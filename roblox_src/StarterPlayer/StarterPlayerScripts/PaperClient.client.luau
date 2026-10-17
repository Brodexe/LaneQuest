-- PaperClient: 2.5D movement, lane changes, side camera, grab/throw/slap input, ragdoll response, control hint, music.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("PaperWorkshop")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local Remotes = Shared:WaitForChild("Remotes")
local map = workspace:WaitForChild("PaperWorkshop")
local propsFolder = map:WaitForChild("MovableProps")
local camera = workspace.CurrentCamera

---------------------------------------------------------------- state
local char, hum, hrp
local lane = 1
local shift -- active lane slide: { from, to, t0 }
local moveX = 0 -- smoothed horizontal input, -1..1
local facing = 1
local ragdolled, resetting = false, false
local heldProp, grabAskedAt = nil, 0
local lastGrounded, jumpPressedAt, jumpedAt = 0, -1, 0
local fallSpeed = 0
local spawnTime = 0
local lastSlap = 0
local camPos, camY, camLaneZ, lookAhead
local cue -- brief camera emphasis from the server: { focus, distance, t0, duration }
local rShoulder, lShoulder
local gestureId = 0

local function inside(part, pos)
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

local zones = {}
for _, z in ipairs(CollectionService:GetTagged("LaneZone")) do
	table.insert(zones, z)
end

---------------------------------------------------------------- arm poses (offsets layered onto the animated shoulders every frame)
-- Newer avatar joints lock C0, so poses ride on top of the animation through Transform instead.
local armOffset = { r = Instance.new("CFrameValue"), l = Instance.new("CFrameValue") }
local applied = {}

local function tweenArm(side, info, target)
	TweenService:Create(armOffset[side], info, { Value = target }):Play()
end

local function applyArm(joint, offset)
	local t = joint.Transform
	local last = applied[joint]
	if last and t == last.written then
		t = last.base -- the animation didn't rewrite this joint this frame: don't stack the offset
	end
	local w = t * offset
	joint.Transform = w
	applied[joint] = { base = t, written = w }
end

local function isR15()
	return hum and hum.RigType == Enum.HumanoidRigType.R15
end

local function raise(right, deg)
	if isR15() then
		return CFrame.Angles(math.rad(deg), 0, 0)
	end
	return CFrame.Angles(0, 0, math.rad(right and deg or -deg))
end

local function setHoldPose(on)
	gestureId += 1
	local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tweenArm("r", info, on and raise(true, 80) or CFrame.identity)
	tweenArm("l", info, on and raise(false, 80) or CFrame.identity)
end

local function swingArm()
	gestureId += 1
	local id = gestureId
	local up = isR15() and CFrame.Angles(math.rad(130), 0, math.rad(-15)) or raise(true, 150)
	local down = isR15() and CFrame.Angles(math.rad(45), math.rad(-35), 0) or raise(true, 50)
	tweenArm("r", TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), up)
	task.delay(0.07, function()
		if id ~= gestureId then
			return
		end
		tweenArm("r", TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), down)
		task.delay(0.12, function()
			if id ~= gestureId then
				return
			end
			tweenArm("r", TweenInfo.new(0.16), CFrame.identity)
		end)
	end)
end

RunService.PreSimulation:Connect(function()
	if rShoulder and rShoulder.Parent then
		applyArm(rShoulder, armOffset.r.Value)
	end
	if lShoulder and lShoulder.Parent then
		applyArm(lShoulder, armOffset.l.Value)
	end
end)

---------------------------------------------------------------- character
local function onCharacter(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	hrp = c:WaitForChild("HumanoidRootPart")
	hum.WalkSpeed = Config.WALK_SPEED
	hum.UseJumpPower = false
	hum.JumpHeight = Config.JUMP_HEIGHT
	hum.AutoRotate = true
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	lane = Config.nearestLane(hrp.Position.Z)
	player:SetAttribute("Lane", lane)
	shift, moveX, facing = nil, 0, 1
	ragdolled, resetting, heldProp = false, false, nil
	spawnTime = os.clock()
	fallSpeed = 0
	camPos = nil
	rShoulder, lShoulder = nil, nil
	armOffset.r.Value, armOffset.l.Value = CFrame.identity, CFrame.identity
	applied = {}
	task.spawn(function()
		if hum.RigType == Enum.HumanoidRigType.R15 then
			local ra, la = c:WaitForChild("RightUpperArm", 5), c:WaitForChild("LeftUpperArm", 5)
			rShoulder = ra and ra:WaitForChild("RightShoulder", 5)
			lShoulder = la and la:WaitForChild("LeftShoulder", 5)
		else
			local torso = c:WaitForChild("Torso", 5)
			rShoulder = torso and torso:WaitForChild("Right Shoulder", 5)
			lShoulder = torso and torso:WaitForChild("Left Shoulder", 5)
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------- actions
local function nearestGrabbable()
	local best, bestScore
	local p = hrp.Position
	for _, prop in ipairs(CollectionService:GetTagged("Grabbable")) do
		if prop:IsDescendantOf(workspace) and not prop:GetAttribute("HeldBy") then
			local d = prop.Position - p
			local gap = math.abs(d.X) - prop.Size.X / 2 - 1
			if gap <= Config.GRAB_RANGE and math.abs(d.Z) < 2.5 and math.abs(d.Y) < prop.Size.Y / 2 + 3 then
				local score = gap + ((math.sign(d.X) ~= facing) and 1 or 0) -- prefer what's in front of you
				if not bestScore or score < bestScore then
					best, bestScore = prop, score
				end
			end
		end
	end
	return best
end

local function tryGrab()
	if heldProp or ragdolled or resetting or not hrp then
		return
	end
	local prop = nearestGrabbable()
	if prop then
		heldProp = prop
		grabAskedAt = os.clock()
		Remotes.Grab:FireServer(prop)
		setHoldPose(true)
	end
end

local function release()
	if not heldProp then
		return
	end
	heldProp = nil
	setHoldPose(false)
	Remotes.Release:FireServer()
end

local function throw()
	if not heldProp or ragdolled or resetting then
		return
	end
	heldProp = nil
	Remotes.Throw:FireServer()
	swingArm()
	tweenArm("l", TweenInfo.new(0.2), CFrame.identity)
end

local function slap()
	-- hands full: slapping waits until you drop (release E) or throw (right click)
	if heldProp or ragdolled or resetting or not hrp then
		return
	end
	local now = os.clock()
	if now - lastSlap < Config.SLAP_COOLDOWN then
		return
	end
	lastSlap = now
	swingArm()
	Remotes.Slap:FireServer()
end

local function selfDestruct()
	if resetting or not hrp then
		return
	end
	resetting = true
	if heldProp then
		heldProp = nil
		setHoldPose(false)
	end
	Remotes.SelfDestruct:FireServer()
end

UserInputService.InputBegan:Connect(function(io, processed)
	if processed then
		return
	end
	local k = io.KeyCode
	if k == Enum.KeyCode.Space then
		jumpPressedAt = os.clock()
	elseif k == Enum.KeyCode.E then
		tryGrab()
	elseif k == Enum.KeyCode.Q then
		selfDestruct()
	elseif io.UserInputType == Enum.UserInputType.MouseButton1 then
		slap()
	elseif io.UserInputType == Enum.UserInputType.MouseButton2 then
		throw()
	end
end)

UserInputService.InputEnded:Connect(function(io)
	if io.KeyCode == Enum.KeyCode.E then
		release()
	end
end)

---------------------------------------------------------------- ragdoll (server toggles the joints, we hand the humanoid over to physics)
Remotes.RagdollState.OnClientEvent:Connect(function(on, knock)
	if not (hum and hrp) then
		return
	end
	if on then
		ragdolled = true
		if heldProp then
			heldProp = nil
			setHoldPose(false)
		end
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		if knock then
			hrp.AssemblyLinearVelocity = knock
		end
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, (math.random() - 0.5) * 8)
	else
		ragdolled = false
		local p = hrp.Position + Vector3.new(0, 1.2, 0)
		hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(facing, 0, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		fallSpeed = 0
	end
end)

---------------------------------------------------------------- movement, lane changes and lane lock (before physics)
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true

local function spaceFree(z)
	overlap.FilterDescendantsInstances = heldProp and { char, heldProp } or { char }
	local p = hrp.Position
	return #workspace:GetPartBoundsInBox(CFrame.new(p.X, p.Y + 0.4, z), Vector3.new(1.6, 4, 1.4), overlap) == 0
end

RunService.PreSimulation:Connect(function(dt)
	if not (hum and hrp and hrp.Parent) or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	local right = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)
	local left = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
	local raw = (right and 1 or 0) - (left and 1 or 0)
	if ragdolled or resetting then
		raw = 0
	end
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	if grounded then
		lastGrounded = now
	end

	-- weighted acceleration: quick but not instant, softer in the air
	local speeding = raw ~= 0 and (moveX == 0 or math.sign(raw) == math.sign(moveX))
	local rate = speeding and (grounded and Config.GROUND_ACCEL or Config.AIR_ACCEL) or (grounded and Config.GROUND_DECEL or Config.AIR_DECEL)
	if moveX < raw then
		moveX = math.min(raw, moveX + rate * dt)
	else
		moveX = math.max(raw, moveX - rate * dt)
	end
	if raw ~= 0 then
		facing = raw
	end

	if not ragdolled then
		hum:Move(Vector3.new(moveX, 0, 0), false)
		-- jump with input buffer and coyote time
		if jumpPressedAt > 0 and now - jumpPressedAt <= Config.JUMP_BUFFER and not resetting then
			if grounded and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
				hum.Jump = true
				jumpPressedAt, jumpedAt = -1, now
			elseif not grounded and now - lastGrounded <= Config.COYOTE_TIME and now - jumpedAt > 0.3 then
				local v = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * workspace.Gravity * Config.JUMP_HEIGHT), v.Z)
				jumpPressedAt, jumpedAt = -1, now
			end
		end
		-- lane changes only inside designated zones, walking in the zone's direction
		if not shift and raw ~= 0 then
			for _, z in ipairs(zones) do
				if z:GetAttribute("FromLane") == lane and z:GetAttribute("Dir") == raw and inside(z, hrp.Position) then
					local to = z:GetAttribute("ToLane")
					if spaceFree(Config.LANES[to]) then
						shift = { from = Config.LANES[lane], to = Config.LANES[to], t0 = now }
						lane = to
						player:SetAttribute("Lane", lane)
					end
					break
				end
			end
		end
	end

	-- hold the body on its lane plane (smoothly slide during a lane change)
	if not shift and math.abs(hrp.Position.Z - Config.LANES[lane]) > 3 then
		lane = Config.nearestLane(hrp.Position.Z)
		player:SetAttribute("Lane", lane)
	end
	local tz = Config.LANES[lane]
	if shift then
		local k = math.min((now - shift.t0) / Config.LANE_SHIFT_TIME, 1)
		k = k * k * (3 - 2 * k)
		tz = shift.from + (shift.to - shift.from) * k
		if k >= 1 then
			shift = nil
		end
	end
	local p, v = hrp.Position, hrp.AssemblyLinearVelocity
	if math.abs(p.Z - tz) > 0.01 then
		hrp.CFrame = hrp.CFrame + Vector3.new(0, 0, tz - p.Z)
	end
	if math.abs(v.Z) > 0.01 then
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
	end
end)

---------------------------------------------------------------- after physics: hard-landing ragdoll check, grab confirmation
RunService.Heartbeat:Connect(function()
	if not (hrp and hrp.Parent and hum) then
		return
	end
	if hum.FloorMaterial == Enum.Material.Air then
		fallSpeed = math.max(fallSpeed, -hrp.AssemblyLinearVelocity.Y)
	else
		if fallSpeed > Config.RAGDOLL_FALL_SPEED and not ragdolled and not resetting and os.clock() - spawnTime > 1.5 then
			Remotes.Impact:FireServer()
		end
		fallSpeed = 0
	end
	if heldProp and not UserInputService:IsKeyDown(Enum.KeyCode.E) then
		release()
	end
	-- the server refused the grab (or dropped it): let go locally too
	if heldProp and os.clock() - grabAskedAt > 0.5 and heldProp:GetAttribute("HeldBy") ~= player.UserId then
		heldProp = nil
		setHoldPose(false)
	end
end)

---------------------------------------------------------------- side camera
local occluders = {}
for _, o in ipairs(CollectionService:GetTagged("Occluder")) do
	local cf, s = o.CFrame, o.Size
	local halfX = math.abs(cf.RightVector.X) * s.X / 2 + math.abs(cf.UpVector.X) * s.Y / 2 + math.abs(cf.LookVector.X) * s.Z / 2
	table.insert(occluders, { part = o, halfX = halfX })
end
local fadeTimer = 0

RunService:BindToRenderStep("PaperCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.CAMERA_FOV
	if not (hrp and hrp.Parent) then
		return
	end
	local p = hrp.Position
	if camPos and math.abs(p.X - camPos.X) > 90 then
		camPos = nil -- we were moved to another area: snap instead of sliding across the world
	end
	local area = Areas.get(player:GetAttribute("Area"))
	local maxX = (area.camMaxXOpen and map:GetAttribute("PassageOpen")) and area.camMaxXOpen or area.camMaxX
	local laneTarget = shift and shift.to or Config.LANES[lane]
	if not camPos then
		camLaneZ, camY, lookAhead = laneTarget, p.Y, facing * Config.CAMERA_LOOKAHEAD
	end
	lookAhead += (facing * Config.CAMERA_LOOKAHEAD - lookAhead) * math.min(1, dt * 1.5)
	-- restrained vertical tracking: follow freely when grounded or dropping, use a dead zone mid-jump
	local dy = p.Y - camY
	local grounded = hum and hum.FloorMaterial ~= Enum.Material.Air
	if grounded or dy < -Config.CAMERA_Y_DEADZONE * 2 then
		camY += dy * math.min(1, dt * Config.CAMERA_Y_SPEED)
	elseif math.abs(dy) > Config.CAMERA_Y_DEADZONE then
		camY += (dy - math.sign(dy) * Config.CAMERA_Y_DEADZONE) * math.min(1, dt * Config.CAMERA_Y_SPEED)
	end
	camLaneZ += (laneTarget - camLaneZ) * math.min(1, dt * Config.CAMERA_LANE_SPEED)
	local fx = math.clamp(p.X + lookAhead, area.camMinX, maxX)
	local desired = Vector3.new(fx, camY + Config.CAMERA_HEIGHT, camLaneZ + (area.camDistance or Config.CAMERA_DISTANCE))
	if not camPos then
		camPos = desired
	else
		camPos = Vector3.new(camPos.X + (desired.X - camPos.X) * math.min(1, dt * Config.CAMERA_X_SPEED), desired.Y, desired.Z)
	end
	local camCF = CFrame.lookAt(camPos, Vector3.new(camPos.X, camY + 1, camLaneZ))
	if cue then
		local k = (os.clock() - cue.t0) / cue.duration
		if k >= 1 then
			cue = nil
		else
			local w = math.min(1, math.sin(k * math.pi) * 1.7)
			w = w * w * (3 - 2 * w)
			local cuePos = cue.focus + Vector3.new(0, 3, cue.distance)
			camCF = camCF:Lerp(CFrame.lookAt(cuePos, cue.focus), w)
		end
	end
	camera.CFrame = camCF

	-- fade cardboard flats that stand between the camera and you
	fadeTimer += dt
	if fadeTimer >= 0.1 then
		fadeTimer = 0
		for _, o in ipairs(occluders) do
			local part = o.part
			local front = part.Position.Z > p.Z + 1.5
			local near = math.abs(part.Position.X - p.X) < o.halfX + 8
			local target = (front and near) and 0.72 or 0
			part.LocalTransparencyModifier += (target - part.LocalTransparencyModifier) * 0.45
		end
	end
end)

---------------------------------------------------------------- travel: snap the camera and lane after a move, accept camera cues
task.spawn(function()
	Remotes:WaitForChild("Transition").OnClientEvent:Connect(function(phase)
		if phase == "open" then
			camPos, cue, shift = nil, nil, nil
			if hrp then
				lane = Config.nearestLane(hrp.Position.Z)
				player:SetAttribute("Lane", lane)
			end
		end
	end)
	Remotes:WaitForChild("CameraCue").OnClientEvent:Connect(function(focus, distance, duration)
		cue = { focus = focus, distance = distance or 60, t0 = os.clock(), duration = duration or 2.5 }
	end)
end)

---------------------------------------------------------------- one small control card, then it gets out of the way
local function showHint()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkshopHint"
	gui.ResetOnSpawn = false
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.new(0, 18, 1, -18)
	card.Size = UDim2.fromOffset(262, 116)
	card.Rotation = -1.5
	card.BackgroundColor3 = Color3.fromRGB(218, 182, 136)
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(146, 108, 70)
	stroke.Thickness = 2
	stroke.Parent = card
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(14, 8)
	text.Size = UDim2.new(1, -24, 1, -16)
	text.FontFace = Font.fromEnum(Enum.Font.PatrickHand)
	text.TextSize = 19
	text.TextColor3 = Color3.fromRGB(62, 50, 42)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = "A / D  run        Space  jump\nhold E  grab, let go to drop\nleft click  slap     right click  throw\nQ  dramatic reset"
	text.Parent = card
	card.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	task.delay(12, function()
		local info = TweenInfo.new(1.5)
		TweenService:Create(card, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		TweenService:Create(text, info, { TextTransparency = 1 }):Play()
		task.wait(1.6)
		gui:Destroy()
	end)
end
showHint()

