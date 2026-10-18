-- Beetle: the Wind-Up Workshop Beetle. Idle -> wind up -> charge -> dizzy -> walk home; a fast prop staggers it.
-- Its charge pops anyone it catches in its layer; step back a layer (W) or jump onto its back to let it pass.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("PaperWorkshop"):WaitForChild("Config"))
local beetle = workspace:WaitForChild("PaperWorkshop"):WaitForChild("Boss"):WaitForChild("WindUpBeetle")
local shell = beetle.PrimaryPart
local head = beetle:WaitForChild("Head")
local key = beetle:WaitForChild("Key")
local BeetleSlapped = script.Parent:WaitForChild("BeetleSlapped")
local HurtPlayer = script.Parent:WaitForChild("HurtPlayer")
local home: CFrame = beetle:GetAttribute("Home")

local function playAt(position, soundKey, volume, speed)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = position
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds[soundKey]
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.RollOffMinDistance = 45
	s.RollOffMaxDistance = 220
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 5)
end

---------------------------------------------------------------- key on its own weld so it can turn
for _, p in ipairs(beetle:GetChildren()) do
	if p.Name == "Key" or p.Name == "KeyBow" then
		local wc = p:FindFirstChildOfClass("WeldConstraint")
		if wc then
			wc:Destroy()
		end
	end
end
local keyWeld = Instance.new("Weld")
keyWeld.Part0 = shell
keyWeld.Part1 = key
keyWeld.C0 = shell.CFrame:ToObjectSpace(key.CFrame)
keyWeld.Parent = key
for _, p in ipairs(beetle:GetChildren()) do
	if p.Name == "KeyBow" then
		local w = Instance.new("WeldConstraint")
		w.Part0 = key
		w.Part1 = p
		w.Parent = p
	end
end
local keyBaseC0 = keyWeld.C0
local keyAngle = 0

---------------------------------------------------------------- physical drive (bounded align constraints)
local att = Instance.new("Attachment")
att.Name = "Drive"
att.Parent = shell
local ap = Instance.new("AlignPosition")
ap.Mode = Enum.PositionAlignmentMode.OneAttachment
ap.Attachment0 = att
ap.MaxForce = 80000
ap.Responsiveness = 18
ap.MaxVelocity = 40
ap.Position = home.Position
ap.Parent = shell
local ao = Instance.new("AlignOrientation")
ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
ao.Attachment0 = att
ao.MaxTorque = 400000
ao.Responsiveness = 14
ao.CFrame = home.Rotation
ao.Parent = shell
shell.Anchored = false
pcall(function()
	shell:SetNetworkOwner(nil)
end)

---------------------------------------------------------------- state machine
local state, stateT = "Idle", os.clock()
local nextCharge = 0
local chargeTo = math.max(home.X - Config.BEETLE_CHARGE_DISTANCE, Config.BEETLE_MIN_X)
local returnFrom = home.X
local hopUntil, hopDir = 0, 1
local hitCooldown = {}
local propVelocity = {} -- each prop's velocity from the previous frame (Touched fires after the bounce)

local function setState(s)
	state = s
	stateT = os.clock()
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- someone standing on the stage floor in front of it (riding on its back doesn't count)
local function findTarget()
	local sx = shell.Position.X
	for _, player in ipairs(Players:GetPlayers()) do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local p = hrp.Position
			if p.X > 102.5 and p.X < sx - 1 and sx - p.X <= Config.BEETLE_TRIGGER_RANGE and math.abs(p.Z) < 2 and p.Y < 10 then
				return true
			end
		end
	end
	return false
end

local function hardReset()
	shell.Anchored = true
	beetle:PivotTo(home)
	shell.AssemblyLinearVelocity = Vector3.zero
	shell.AssemblyAngularVelocity = Vector3.zero
	shell.Anchored = false
	pcall(function()
		shell:SetNetworkOwner(nil)
	end)
	ao.Enabled = true
	ao.Responsiveness = 14
	ap.MaxForce = 80000
	ap.Position = home.Position
	setState("Idle")
	nextCharge = os.clock() + Config.BEETLE_COOLDOWN
end

local function stagger(dir)
	if state == "Stagger" then
		return
	end
	setState("Stagger")
	ao.Enabled = false
	ap.MaxForce = 25000
	ap.Position = Vector3.new(math.clamp(shell.Position.X + dir * 1.5, Config.BEETLE_MIN_X, home.X + 0.5), home.Y + 0.6, 0)
	local m = shell.AssemblyMass
	shell:ApplyImpulse(Vector3.new(dir * 8, 14, 0) * m)
	shell:ApplyAngularImpulse(Vector3.new(0, 0, -dir * 55) * m)
	playAt(shell.Position, "BodyFall", 0.8, 0.8)
	playAt(shell.Position, "Cardboard", 0.8, 0.9)
end

-- riding on its back is safe: only feet below the top of the shell count as caught
local function caught(player, hrp)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local feet = hrp.Position.Y - (hum and hum.HipHeight or 2) - hrp.Size.Y / 2
	if feet > shell.Position.Y + shell.Size.Y / 2 - 0.5 then
		return
	end
	if hitCooldown[player] and os.clock() - hitCooldown[player] < 1.5 then
		return
	end
	hitCooldown[player] = os.clock()
	playAt(hrp.Position, "Cardboard", 0.9, 0.8)
	HurtPlayer:Fire(player, shell.Position, 0, 0, true)
end

local function onTouched(other)
	-- a thrown or slapped prop arriving fast enough staggers it
	if CollectionService:HasTag(other, "Prop") and not other:GetAttribute("HeldBy") then
		local v = propVelocity[other] or other.AssemblyLinearVelocity
		local rel = v - shell.AssemblyLinearVelocity
		if rel.Magnitude >= Config.BEETLE_STAGGER_SPEED then
			stagger(rel.X >= 0 and 1 or -1)
		end
		return
	end
	if state ~= "Charge" then
		return
	end
	local model = other:FindFirstAncestorOfClass("Model")
	local player = model and Players:GetPlayerFromCharacter(model)
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if player and hrp then
		caught(player, hrp)
	end
end
shell.Touched:Connect(onTouched)
head.Touched:Connect(onTouched)

BeetleSlapped.Event:Connect(function(_, dir)
	if state == "Stagger" then
		return
	end
	hopUntil = os.clock() + 0.22
	hopDir = dir
	playAt(shell.Position, "WoodKnock", 0.6, 1.2)
	if state == "Idle" then
		nextCharge = math.max(nextCharge, os.clock() + 0.6)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for _, p in ipairs(CollectionService:GetTagged("Prop")) do
		propVelocity[p] = p.AssemblyLinearVelocity
	end
	local now = os.clock()
	local t = now - stateT
	local pos, tilt = home.Position, CFrame.identity
	if state == "Idle" then
		pos = home.Position + Vector3.new(0, math.sin(now * 2.2) * 0.08, 0)
		tilt = CFrame.Angles(0, 0, math.sin(now * 1.3) * 0.02)
		keyAngle += dt * 1.2
		if now > nextCharge and findTarget() then
			setState("Telegraph")
			playAt(shell.Position, "WindUp", 0.8, 1.4)
		end
	elseif state == "Telegraph" then
		local k = math.min(t / Config.BEETLE_TELEGRAPH_TIME, 1)
		pos = home.Position + Vector3.new(0.6 * k, 0, 0)
		tilt = CFrame.Angles(0, 0, -math.rad(14) * math.sin(k * math.pi / 2) + math.sin(now * 40) * 0.02)
		keyAngle += dt * (6 + 30 * k)
		if k >= 1 then
			setState("Charge")
			playAt(shell.Position, "Ratchet", 0.7, 1.3)
		end
	elseif state == "Charge" then
		local k = math.min(t / Config.BEETLE_CHARGE_TIME, 1)
		pos = Vector3.new(lerp(home.X + 0.6, chargeTo, 1 - (1 - k) * (1 - k)), home.Y, 0)
		tilt = CFrame.Angles(0, 0, math.rad(4))
		keyAngle += dt * 40
		-- touch events can miss a fast charge: anyone in its path in its layer is caught
		local front = shell.Position.X - shell.Size.X / 2 - 2.8
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and math.abs(hrp.Position.Z - shell.Position.Z) < 1.9 and hrp.Position.X > front - 0.8 and hrp.Position.X < shell.Position.X + shell.Size.X / 2 then
				caught(player, hrp)
			end
		end
		if k >= 1 then
			setState("Dizzy")
		end
	elseif state == "Dizzy" then
		pos = Vector3.new(chargeTo, home.Y, 0)
		tilt = CFrame.Angles(0, math.sin(now * 9) * 0.12, math.sin(now * 7) * 0.05)
		keyAngle += dt * 3
		if t >= Config.BEETLE_DIZZY_TIME then
			returnFrom = chargeTo
			setState("Return")
		end
	elseif state == "Return" then
		local k = math.min(t / Config.BEETLE_RETURN_TIME, 1)
		local s = k * k * (3 - 2 * k)
		pos = Vector3.new(lerp(returnFrom, home.X, s), home.Y + math.abs(math.sin(now * 12)) * 0.12, 0)
		tilt = CFrame.Angles(0, 0, math.sin(now * 12) * 0.03)
		keyAngle += dt * 2
		if k >= 1 then
			setState("Idle")
			nextCharge = now + Config.BEETLE_COOLDOWN
		end
	elseif state == "Stagger" then
		keyAngle -= dt * 25
		pos = ap.Position
		if not ao.Enabled and t > 0.7 then
			ao.Enabled = true
			ao.Responsiveness = 4
		end
		if t >= Config.BEETLE_STAGGER_TIME then
			ao.Responsiveness = 14
			ap.MaxForce = 80000
			returnFrom = math.clamp(shell.Position.X, Config.BEETLE_MIN_X, home.X + 1)
			setState("Return")
		end
	end
	if state ~= "Stagger" and now < hopUntil then
		pos += Vector3.new(0, 1.1, 0)
		tilt = tilt * CFrame.Angles(0, 0, hopDir * 0.12)
	end
	ap.Position = pos
	ao.CFrame = home.Rotation * tilt
	keyWeld.C0 = keyBaseC0 * CFrame.Angles(0, keyAngle, 0)
end)

-- it can never wander off the stage or out of the world
task.spawn(function()
	while true do
		task.wait(0.5)
		local p = shell.Position
		if p.Y < 0 or p.X < 104 or p.X > 124 or math.abs(p.Z) > 4 then
			hardReset()
		end
	end
end)
