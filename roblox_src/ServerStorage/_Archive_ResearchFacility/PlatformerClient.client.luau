-- PlatformerClient: 2.5D movement, lane shifting, side camera, crate grab, swinging, ledge grab, occluder fading.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Platformer")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local GrabCrate = Remotes:WaitForChild("GrabCrate")
local ResetCrates = Remotes:WaitForChild("ResetCrates")
local SwingSync = Remotes:WaitForChild("SwingSync")
local Collected = Remotes:WaitForChild("Collected")
local Replay = Remotes:WaitForChild("Replay")
local level = workspace:WaitForChild("ResearchFacility")
local camera = workspace.CurrentCamera

-- take over movement input (StarterPlayer movement modes are Scriptable; also disable PlayerModule if present)
task.spawn(function()
	local pm = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
	if pm then
		pcall(function()
			require(pm):GetControls():Disable()
		end)
	end
end)
do
	local CAS = game:GetService("ContextActionService")
	local K = Enum.KeyCode
	CAS:BindActionAtPriority("PlatformerSink", function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, K.W, K.A, K.S, K.D, K.Up, K.Down, K.Left, K.Right, K.Space)
end

---------------------------------------------------------------- state
local char, hum, hrp
local lane = 1
local shifting = false
local facing = 1
local mode = "normal" -- normal | swing | ledge | climb
local input = { left = 0, right = 0, padX = 0, touchX = 0 }
local grabbed, grabOffset, grabTime
local swing -- {model, theta, omega, L, pivot, offsets}
local swingCooldown, lastSwing = 0, nil
local ledge -- {wallX, top, dir}
local ledgeCooldown = 0
local launch -- {vx, t}
local syncTimer = 0
local camPos

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.RespectCanCollide = true

local function setHint(text)
	if player:GetAttribute("Hint") ~= text then
		player:SetAttribute("Hint", text)
	end
end

local function notify(text)
	player:SetAttribute("LocalNotify", text .. "#" .. tostring(os.clock()))
end

local function moveInput()
	return math.clamp(input.right - input.left + input.padX + input.touchX, -1, 1)
end

local function laneZ()
	return Config.laneZ(lane)
end

---------------------------------------------------------------- crates
local function releaseCrate()
	if grabbed then
		GrabCrate:FireServer(grabbed, false)
		grabbed = nil
	end
	if hum then
		hum.AutoRotate = true
		hum.WalkSpeed = Config.WALK_SPEED
	end
end

local function findCrate()
	local best, bestGap
	for _, crate in ipairs(CollectionService:GetTagged("Crate")) do
		if crate:GetAttribute("Lane") == lane then
			local dx = crate.Position.X - hrp.Position.X
			local gap = math.abs(dx) - crate.Size.X / 2 - 1
			local bottom = crate.Position.Y - crate.Size.Y / 2
			local top = crate.Position.Y + crate.Size.Y / 2
			if gap < Config.GRAB_RANGE and bottom < hrp.Position.Y + 1.5 and top > hrp.Position.Y - 2.5 then
				if not bestGap or gap < bestGap then
					best, bestGap = crate, gap
				end
			end
		end
	end
	return best
end

local function grabCrate(crate)
	local by = crate:GetAttribute("GrabbedBy")
	if by and by ~= player.UserId then
		notify("Someone else is holding that")
		return
	end
	grabbed = crate
	grabTime = os.clock()
	grabOffset = crate.Position.X - hrp.Position.X
	facing = grabOffset > 0 and 1 or -1
	GrabCrate:FireServer(crate, true)
	hum.AutoRotate = false
	local p = hrp.Position
	hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(facing, 0, 0))
	local w = crate:GetAttribute("Weight") or 1
	hum.WalkSpeed = Config.WALK_SPEED / (1 + 0.3 * (w - 1))
end

local function updateCrate()
	if not grabbed then
		return
	end
	if not grabbed.Parent then
		releaseCrate()
		return
	end
	local by = grabbed:GetAttribute("GrabbedBy")
	if os.clock() - grabTime > 0.6 and by ~= player.UserId then
		releaseCrate()
		return
	end
	local dx = grabbed.Position.X - hrp.Position.X
	local dy = grabbed.Position.Y - hrp.Position.Y
	if math.abs(dx) > math.abs(grabOffset) + 4 or math.abs(dy) > grabbed.Size.Y / 2 + 4 then
		releaseCrate()
		return
	end
	local desired = hrp.Position.X + grabOffset
	local v = grabbed.AssemblyLinearVelocity
	local vx = math.clamp((desired - grabbed.Position.X) * 12, -24, 24)
	grabbed.AssemblyLinearVelocity = Vector3.new(vx, v.Y, 0)
	local p = hrp.Position
	hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(facing, 0, 0))
end

---------------------------------------------------------------- lane shifting
local function zoneAllows(from, to)
	local pos = hrp.Position
	for _, z in ipairs(CollectionService:GetTagged("LaneShift")) do
		local rel = z.CFrame:PointToObjectSpace(pos)
		local half = z.Size / 2
		if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 1 and math.abs(rel.Z) <= half.Z then
			local lanes = "," .. (z:GetAttribute("Lanes") or "") .. ","
			if lanes:find("," .. from .. ",") and lanes:find("," .. to .. ",") then
				return true
			end
		end
	end
	return false
end

local function spaceFree(targetZ)
	overlapParams.FilterDescendantsInstances = { char }
	local p = hrp.Position
	local parts = workspace:GetPartBoundsInBox(CFrame.new(p.X, p.Y + 0.3, targetZ), Vector3.new(1.8, 4.2, 1.6), overlapParams)
	for _, part in ipairs(parts) do
		if part.CanCollide and not part:IsDescendantOf(char) then
			return false
		end
	end
	return true
end

local function tryShift(delta)
	if mode ~= "normal" or shifting or not hrp then
		return
	end
	local target = lane + delta
	if target < 1 or target > #Config.LANE_Z then
		return
	end
	if not zoneAllows(lane, target) then
		return
	end
	if not spaceFree(Config.laneZ(target)) then
		notify("That plane is blocked here")
		return
	end
	releaseCrate()
	lane = target
	shifting = true
	player:SetAttribute("Lane", lane)
end

local function lockLane()
	local tz = laneZ()
	local p = hrp.Position
	local err = tz - p.Z
	local v = hrp.AssemblyLinearVelocity
	if shifting then
		if math.abs(err) < 0.2 then
			shifting = false
			hrp.CFrame = hrp.CFrame + Vector3.new(0, 0, err)
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
		else
			local vz = math.clamp(err * 14, -Config.LANE_SHIFT_SPEED, Config.LANE_SHIFT_SPEED)
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, vz)
		end
	else
		if math.abs(err) > 0.01 then
			hrp.CFrame = hrp.CFrame + Vector3.new(0, 0, err)
		end
		if math.abs(v.Z) > 0.01 then
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
		end
	end
end

---------------------------------------------------------------- swinging
local HANG = 2.6 -- grip to root distance

local function swingParts(model, theta)
	local pivot = model:GetAttribute("Pivot")
	local base = CFrame.new(pivot) * CFrame.Angles(0, 0, theta)
	local offsets = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Pivot" then
			offsets[p] = base:ToObjectSpace(p.CFrame)
		end
	end
	return offsets
end

local function startSwing(model)
	local handle = model.PrimaryPart
	local grip = handle and handle:FindFirstChild("Grip")
	if not grip then
		return
	end
	releaseCrate()
	local pivot = model:GetAttribute("Pivot")
	local L = model:GetAttribute("Length")
	local d = grip.WorldPosition - pivot
	local theta = math.atan2(d.X, -d.Y)
	local serverTheta = model:GetAttribute("Theta") or theta
	local Leff = L + HANG
	local tangent = Vector3.new(math.cos(theta), math.sin(theta), 0)
	local v = hrp.AssemblyLinearVelocity
	local omega = (model:GetAttribute("Omega") or 0) * 0.5 + (v:Dot(tangent) / Leff) * 0.6
	swing = {
		model = model,
		theta = theta,
		omega = omega,
		L = Leff,
		pivot = pivot,
		offsets = swingParts(model, serverTheta),
	}
	mode = "swing"
	launch = nil
	hum.PlatformStand = true
	setHint("A / D  swing      SPACE  let go")
end

local function endSwing(jump)
	if not swing then
		return
	end
	local s = swing
	swing = nil
	mode = "normal"
	local tangent = Vector3.new(math.cos(s.theta), math.sin(s.theta), 0)
	local vel = tangent * s.L * s.omega
	if jump then
		vel += Vector3.new(0, Config.SWING_RELEASE_BOOST, 0)
	end
	hum.PlatformStand = false
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	hrp.AssemblyLinearVelocity = vel
	launch = { vx = vel.X, t = 1.4 }
	if math.abs(vel.X) > 1 then
		facing = vel.X > 0 and 1 or -1
	end
	swingCooldown = os.clock() + 0.5
	lastSwing = s.model
	SwingSync:FireServer(s.model, s.theta, s.omega * (s.L / (s.L - HANG)) * ((s.L - HANG) / s.L), false)
	setHint("")
end

local function updateSwing(dt)
	local s = swing
	if not s.model.Parent then
		endSwing(false)
		return
	end
	local g = workspace.Gravity
	local steps = 4
	local h = dt / steps
	local mv = moveInput()
	for _ = 1, steps do
		local alpha = -(g / s.L) * math.sin(s.theta) + mv * Config.SWING_PUMP * math.cos(s.theta) - 0.04 * s.omega
		s.omega += alpha * h
		s.theta += s.omega * h
	end
	if math.abs(s.theta) > 1.4 then
		s.theta = math.sign(s.theta) * 1.4
		s.omega = 0
	end
	if mv ~= 0 then
		facing = mv > 0 and 1 or -1
	end
	-- move the suspended object locally so it matches the player exactly
	local rot = CFrame.new(s.pivot) * CFrame.Angles(0, 0, s.theta)
	for p, off in pairs(s.offsets) do
		p.CFrame = rot * off
	end
	local dir = Vector3.new(math.sin(s.theta), -math.cos(s.theta), 0)
	local pos = s.pivot + dir * s.L
	pos = Vector3.new(pos.X, pos.Y, laneZ())
	local yaw = facing > 0 and -math.pi / 2 or math.pi / 2
	hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, s.theta * 0.6) * CFrame.Angles(0, yaw, 0)
	local tangent = Vector3.new(math.cos(s.theta), math.sin(s.theta), 0)
	hrp.AssemblyLinearVelocity = tangent * s.L * s.omega
	hrp.AssemblyAngularVelocity = Vector3.zero
	syncTimer += dt
	if syncTimer > 1 / 15 then
		syncTimer = 0
		SwingSync:FireServer(s.model, s.theta, s.omega, true)
	end
end

local function trySwingCatch(force)
	if mode ~= "normal" or shifting or grabbed then
		return false
	end
	local hands = hrp.Position + Vector3.new(0, 2, 0)
	for _, model in ipairs(CollectionService:GetTagged("Swing")) do
		if model:GetAttribute("Lane") == lane then
			local handle = model.PrimaryPart
			local grip = handle and handle:FindFirstChild("Grip")
			if grip then
				local held = model:GetAttribute("HeldBy")
				local free = not held or held == 0 or held == player.UserId
				local dist = (grip.WorldPosition - hands).Magnitude
				local recent = model == lastSwing and os.clock() < swingCooldown + 0.3
				if free and not recent and dist < Config.SWING_CATCH_RADIUS + (force and 1 or 0) then
					startSwing(model)
					return true
				end
			end
		end
	end
	return false
end

---------------------------------------------------------------- ledges
local function hangCFrame(l)
	local pos = Vector3.new(l.wallX - l.dir * 1.15, l.top - 2.3, laneZ())
	return CFrame.lookAt(pos, pos + Vector3.new(l.dir, 0, 0))
end

local function tryLedge()
	if os.clock() < ledgeCooldown or grabbed or shifting then
		return
	end
	local mv = moveInput()
	if mv == 0 then
		return
	end
	local dir = mv > 0 and 1 or -1
	local v = hrp.AssemblyLinearVelocity
	if v.Y > 10 then
		return
	end
	rayParams.FilterDescendantsInstances = { char }
	local o = hrp.Position
	local low = workspace:Raycast(o + Vector3.new(0, 0.6, 0), Vector3.new(dir * 2.2, 0, 0), rayParams)
	if not low or math.abs(low.Normal.X) < 0.7 then
		return
	end
	if CollectionService:HasTag(low.Instance, "MovingPlatform") or CollectionService:HasTag(low.Instance, "Crate") and low.Instance:GetAttribute("GrabbedBy") then
		return
	end
	local high = workspace:Raycast(o + Vector3.new(0, 3, 0), Vector3.new(dir * 2.2, 0, 0), rayParams)
	if high then
		return
	end
	local down = workspace:Raycast(Vector3.new(low.Position.X + dir * 0.6, o.Y + 3.2, o.Z), Vector3.new(0, -3, 0), rayParams)
	if not down or down.Normal.Y < 0.7 then
		return
	end
	local top = down.Position.Y
	if top - o.Y < 0.3 or top - o.Y > 3.1 then
		return
	end
	-- room to stand on top?
	overlapParams.FilterDescendantsInstances = { char }
	local standPos = Vector3.new(low.Position.X + dir * 1.6, top + 2.8, o.Z)
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(standPos), Vector3.new(1.6, 4.5, 1.4), overlapParams)) do
		if part.CanCollide then
			return
		end
	end
	ledge = { wallX = low.Position.X, top = top, dir = dir }
	mode = "ledge"
	launch = nil
	hum.PlatformStand = true
	setHint("SPACE / W  climb      S  drop")
end

local function dropLedge()
	mode = "normal"
	ledge = nil
	hum.PlatformStand = false
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	ledgeCooldown = os.clock() + Config.LEDGE_COOLDOWN
	setHint("")
end

local function climbLedge()
	if mode ~= "ledge" then
		return
	end
	mode = "climb"
	local l = ledge
	local from = hangCFrame(l).Position
	local to = Vector3.new(l.wallX + l.dir * 1.6, l.top + 3.1, laneZ())
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not hrp or not hrp.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / 0.25, 0, 1)
		-- up first, then over
		local up = math.clamp(a * 1.6, 0, 1)
		local over = math.clamp(a * 1.6 - 0.6, 0, 1)
		local pos = Vector3.new(from.X + (to.X - from.X) * over, from.Y + (to.Y - from.Y) * up, to.Z)
		hrp.CFrame = CFrame.lookAt(pos, pos + Vector3.new(l.dir, 0, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		if a >= 1 then
			conn:Disconnect()
			mode = "normal"
			ledge = nil
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.Landed)
			ledgeCooldown = os.clock() + Config.LEDGE_COOLDOWN
			setHint("")
		end
	end)
end

---------------------------------------------------------------- actions
local function doJump()
	if mode == "swing" then
		endSwing(true)
	elseif mode == "ledge" then
		climbLedge()
	elseif mode == "normal" and hum then
		if grabbed then
			releaseCrate()
		end
		hum.Jump = true
	end
end

local function doGrab()
	if not hrp then
		return
	end
	if mode == "swing" then
		endSwing(false)
		return
	end
	if mode ~= "normal" then
		return
	end
	if grabbed then
		releaseCrate()
		return
	end
	if trySwingCatch(true) then
		return
	end
	local crate = findCrate()
	if crate then
		grabCrate(crate)
	end
end

local function doUp()
	if mode == "ledge" then
		climbLedge()
	else
		tryShift(1)
	end
end

local function doDown()
	if mode == "ledge" then
		dropLedge()
	else
		tryShift(-1)
	end
end

-- exposed for the touch buttons in the HUD
local TouchInput = Instance.new("BindableEvent")
TouchInput.Name = "TouchInput"
TouchInput.Parent = script
TouchInput.Event:Connect(function(action, value)
	if action == "Move" then
		input.touchX = value
	elseif action == "Jump" then
		doJump()
	elseif action == "Grab" then
		doGrab()
	elseif action == "Up" then
		doUp()
	elseif action == "Down" then
		doDown()
	elseif action == "Reset" then
		ResetCrates:FireServer()
	end
end)

local KEY = Enum.KeyCode
UserInputService.InputBegan:Connect(function(io, processed)
	if processed and io.UserInputType == Enum.UserInputType.Keyboard and UserInputService:GetFocusedTextBox() then
		return
	end
	local k = io.KeyCode
	if k == KEY.A or k == KEY.Left then
		input.left = 1
	elseif k == KEY.D or k == KEY.Right then
		input.right = 1
	elseif k == KEY.W or k == KEY.Up or k == KEY.DPadUp then
		doUp()
	elseif k == KEY.S or k == KEY.Down or k == KEY.DPadDown then
		doDown()
	elseif k == KEY.Space or k == KEY.ButtonA then
		doJump()
	elseif k == KEY.E or k == KEY.ButtonX or k == KEY.LeftShift then
		doGrab()
	elseif k == KEY.R or k == KEY.ButtonSelect then
		ResetCrates:FireServer()
	end
end)

UserInputService.InputEnded:Connect(function(io)
	local k = io.KeyCode
	if k == KEY.A or k == KEY.Left then
		input.left = 0
	elseif k == KEY.D or k == KEY.Right then
		input.right = 0
	end
end)

local stickUp = false
UserInputService.InputChanged:Connect(function(io)
	if io.KeyCode == KEY.Thumbstick1 then
		local x = io.Position.X
		input.padX = math.abs(x) > 0.25 and x or 0
		local y = io.Position.Y
		if y > 0.8 and not stickUp then
			stickUp = true
			doUp()
		elseif y < -0.8 and not stickUp then
			stickUp = true
			doDown()
		elseif math.abs(y) < 0.4 then
			stickUp = false
		end
	end
end)

---------------------------------------------------------------- character
local function onCharacter(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	hrp = c:WaitForChild("HumanoidRootPart")
	mode = "normal"
	swing, ledge, launch, grabbed = nil, nil, nil, nil
	shifting = false
	facing = 1
	lane = player:GetAttribute("SpawnLane") or 1
	-- the server sets SpawnLane before/after pivoting; resolve from position as well
	task.delay(0.2, function()
		if hrp and hrp.Parent then
			lane = Config.nearestLane(hrp.Position.Z)
			player:SetAttribute("Lane", lane)
		end
	end)
	player:SetAttribute("Lane", lane)
	hum.WalkSpeed = Config.WALK_SPEED
	hum.UseJumpPower = false
	hum.JumpHeight = Config.JUMP_HEIGHT
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum.Died:Connect(function()
		if swing then
			SwingSync:FireServer(swing.model, swing.theta, swing.omega, false)
			swing = nil
		end
		grabbed = nil
		mode = "dead"
		setHint("")
	end)
	camPos = nil
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------- main loop
local function contextHint()
	if mode ~= "normal" then
		return
	end
	if grabbed then
		setHint("Holding crate  -  E  release")
		return
	end
	local parts = {}
	if lane < #Config.LANE_Z and zoneAllows(lane, lane + 1) then
		table.insert(parts, "W  to " .. Config.LANE_NAMES[lane + 1])
	end
	if lane > 1 and zoneAllows(lane, lane - 1) then
		table.insert(parts, "S  to " .. Config.LANE_NAMES[lane - 1])
	end
	if findCrate() then
		table.insert(parts, "E  grab crate")
	end
	setHint(table.concat(parts, "     "))
end

-- feed the humanoid right before physics so nothing else overrides it
RunService.PreSimulation:Connect(function()
	if hum and hum.Health > 0 then
		hum:Move(mode == "normal" and Vector3.new(moveInput(), 0, 0) or Vector3.zero, false)
	end
end)

local hintTimer = 0
RunService.Heartbeat:Connect(function(dt)
	if not (hrp and hrp.Parent and hum and hum.Health > 0) then
		return
	end
	if mode == "normal" then
		local mv = moveInput()
		if mv ~= 0 and not grabbed then
			facing = mv > 0 and 1 or -1
		end
		lockLane()
		updateCrate()
		local airborne = hum.FloorMaterial == Enum.Material.Air
		if airborne then
			if os.clock() > swingCooldown then
				trySwingCatch(false)
			end
			if mode == "normal" then
				tryLedge()
			end
		end
		-- keep swing momentum after letting go (humanoids otherwise kill air speed)
		if launch and mode == "normal" then
			launch.t -= dt
			if not airborne and launch.t < 1.3 or launch.t <= 0 then
				launch = nil
			else
				launch.vx *= 0.995
				local v = hrp.AssemblyLinearVelocity
				local vx = launch.vx + mv * 6
				if math.abs(vx) < Config.WALK_SPEED then
					launch = nil
				else
					hrp.AssemblyLinearVelocity = Vector3.new(vx, v.Y, v.Z)
				end
			end
		end
	elseif mode == "swing" then
		updateSwing(dt)
	elseif mode == "ledge" then
		hrp.CFrame = hangCFrame(ledge)
		hrp.AssemblyLinearVelocity = Vector3.zero
		if moveInput() == -ledge.dir then
			dropLedge()
		end
	end
	hintTimer += dt
	if hintTimer > 0.15 then
		hintTimer = 0
		contextHint()
	end
end)

---------------------------------------------------------------- camera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = Config.CAMERA_FOV
local lookAhead = 0
RunService:BindToRenderStep("PlatformerCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera.CameraType = Enum.CameraType.Scriptable
	if not (hrp and hrp.Parent) then
		return
	end
	local p = hrp.Position
	lookAhead += (facing * 5 - lookAhead) * math.min(1, dt * 2)
	local focus = Vector3.new(p.X + lookAhead, p.Y + 2, Config.laneZ(lane) * 0.35)
	local desired = Vector3.new(focus.X, focus.Y + Config.CAMERA_HEIGHT, Config.CAMERA_DISTANCE)
	if not camPos then
		camPos = desired
	else
		local a = math.min(1, dt * 6)
		camPos = Vector3.new(
			camPos.X + (desired.X - camPos.X) * a,
			camPos.Y + (desired.Y - camPos.Y) * math.min(1, dt * 4),
			camPos.Z + (desired.Z - camPos.Z) * a
		)
	end
	camera.CFrame = CFrame.lookAt(camPos, Vector3.new(camPos.X, camPos.Y - Config.CAMERA_HEIGHT + 0.5, focus.Z))
end)

---------------------------------------------------------------- fading occluders + collectible animation
local fadeParts = {}
for _, p in ipairs(CollectionService:GetTagged("Fade")) do
	table.insert(fadeParts, p)
end

local collectibles = {}
local taken = {}
for _, c in ipairs(CollectionService:GetTagged("Collectible")) do
	if c:IsDescendantOf(level) then
		collectibles[c] = c.CFrame
	end
end

Collected.OnClientEvent:Connect(function(part, secret)
	taken[part] = true
	part.LocalTransparencyModifier = 1
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = false
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.Volume = secret and 1 or 0.4
	s.PlaybackSpeed = secret and 0.7 or 1.4 + math.random() * 0.2
	s.Parent = workspace
	s:Play()
	game:GetService("Debris"):AddItem(s, 2)
	if secret then
		notify("SECRET FOUND!")
	end
end)

Replay.OnClientEvent:Connect(function() end)
player:GetAttributeChangedSignal("Score"):Connect(function()
	if (player:GetAttribute("Score") or 0) == 0 then
		for part in pairs(taken) do
			part.LocalTransparencyModifier = 0
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = true
			end
		end
		taken = {}
	end
end)

local fadeTimer = 0
RunService.RenderStepped:Connect(function(dt)
	fadeTimer += dt
	if fadeTimer > 0.1 and hrp then
		fadeTimer = 0
		local px = hrp.Position.X
		for _, p in ipairs(fadeParts) do
			local near = math.abs(p.Position.X - px) < p.Size.X / 2 + 40
			local target = (near and (p:GetAttribute("Lane") or 1) < lane) and 0.8 or 0
			p.LocalTransparencyModifier += (target - p.LocalTransparencyModifier) * 0.5
		end
	end
	local t = os.clock()
	for c, cf in pairs(collectibles) do
		if not taken[c] then
			if c:GetAttribute("Secret") then
				c.CFrame = cf * CFrame.new(0, math.sin(t * 2) * 0.3, 0) * CFrame.Angles(0, t * 1.5, 0)
			else
				c.CFrame = cf * CFrame.new(0, math.sin(t * 3 + cf.X) * 0.2, 0)
			end
		end
	end
end)
