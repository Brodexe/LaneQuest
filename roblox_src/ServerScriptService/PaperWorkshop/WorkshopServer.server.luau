-- WorkshopServer: authoritative grab/throw/slap, ragdoll, resets, prop upkeep, secrets and the finish.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("PaperWorkshop")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local map = workspace:WaitForChild("PaperWorkshop")
local propsFolder = map:WaitForChild("MovableProps")
local triggers = map:WaitForChild("Triggers")
local boss = map:WaitForChild("Boss")

-- Remotes (client -> server requests, plus one server -> client state event)
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local GrabRemote = remote("Grab")
local ReleaseRemote = remote("Release")
local ThrowRemote = remote("Throw")
local SlapRemote = remote("Slap")
local ImpactRemote = remote("Impact")
local ResetRemote = remote("SelfDestruct")
local RagdollState = remote("RagdollState")
Remotes.Parent = Shared

-- links with the Beetle script
local function bindable(name)
	local b = Instance.new("BindableEvent")
	b.Name = name
	b.Parent = script.Parent
	return b
end
local BeetleSlapped = bindable("BeetleSlapped")
local RagdollRequest = bindable("RagdollRequest")
local Slapped = bindable("Slapped") -- (part, player, dir) for anything tagged "Slappable"
local ForceRelease = bindable("ForceRelease") -- (player) drop whatever they hold, e.g. before travel

---------------------------------------------------------------- helpers
local function playAt(position, key, volume, speed, lifetime)
	local id = Config.Sounds[key]
	if not id then
		return nil
	end
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = position
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or (0.92 + math.random() * 0.16)
	s.RollOffMinDistance = 45
	s.RollOffMaxDistance = 220
	s.Parent = a
	s:Play()
	Debris:AddItem(a, lifetime or 5)
	return s
end

local burstColors = {
	Color3.fromRGB(218, 182, 136), Color3.fromRGB(242, 232, 206), Color3.fromRGB(84, 136, 134),
	Color3.fromRGB(212, 166, 68), Color3.fromRGB(186, 64, 50),
}
-- real little paper scraps: they flutter out, land, and get tidied away
local function paperBurst(pos, n)
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.45, 0.04, 0.32)
		p.Material = Enum.Material.Plaster
		p.Color = burstColors[math.random(#burstColors)]
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CollisionGroup = "HeldProps"
		p.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Parent = workspace
		p.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 26, 16 + math.random() * 16, (math.random() - 0.5) * 6)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
		Debris:AddItem(p, 2.5 + math.random())
	end
end

local function isInside(part, pos)
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

local function laneZ(z)
	return Config.LANES[Config.nearestLane(z)]
end

---------------------------------------------------------------- per-player state
local charInfo = {} -- motors, ragdoll sockets and limb collision for the current character
local held = {} -- what each player is carrying
local ragdolled = {}
local lastRagdoll = {}
local resetting = {}
local lastSlap = {}
local completed = {}

local function releaseHeld(player, throwVelocity)
	local h = held[player]
	if not h then
		return
	end
	held[player] = nil
	h.ap:Destroy()
	h.ao:Destroy()
	h.hold:Destroy()
	h.grip:Destroy()
	local prop = h.prop
	prop:SetAttribute("HeldBy", nil)
	if prop.Parent then
		pcall(function()
			prop:SetNetworkOwner(nil)
		end)
		if throwVelocity then
			prop.AssemblyLinearVelocity = throwVelocity
			prop.AssemblyAngularVelocity = Vector3.new(0, 0, -math.sign(throwVelocity.X) * 4)
		end
		task.delay(0.35, function()
			if prop.Parent and not prop:GetAttribute("HeldBy") then
				prop.CollisionGroup = "Default"
			end
		end)
	end
end

local function setRagdoll(player, on, duration, knock)
	local char = player.Character
	local info = charInfo[player]
	if not (char and info) then
		return
	end
	if on then
		if ragdolled[player] then
			return
		end
		ragdolled[player] = true
		lastRagdoll[player] = os.clock()
		releaseHeld(player)
		for _, m in ipairs(info.motors) do
			m.Enabled = false
		end
		for _, s in ipairs(info.sockets) do
			s.Enabled = true
		end
		for limb in pairs(info.limbs) do
			limb.CanCollide = true
		end
		RagdollState:FireClient(player, true, knock)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			playAt(hrp.Position, "BodyFall", 0.7)
		end
		if duration then
			task.delay(duration, function()
				if player.Character == char and ragdolled[player] and not resetting[player] then
					setRagdoll(player, false)
				end
			end)
		end
	else
		if not ragdolled[player] then
			return
		end
		ragdolled[player] = nil
		for _, s in ipairs(info.sockets) do
			s.Enabled = false
		end
		for _, m in ipairs(info.motors) do
			m.Enabled = true
		end
		for limb, was in pairs(info.limbs) do
			limb.CanCollide = was
		end
		RagdollState:FireClient(player, false)
	end
end

local function respawn(player, delay)
	if resetting[player] then
		return
	end
	resetting[player] = true
	releaseHeld(player)
	task.delay(delay, function()
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

local function setupCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	task.wait()
	local info = { motors = {}, sockets = {}, limbs = {} }
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Characters"
		elseif d:IsA("Motor6D") and d.Part0 and d.Part1 and d.Name ~= "Root" and d.Name ~= "RootJoint" then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = d.C0
			a0.Parent = d.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = d.C1
			a1.Parent = d.Part1
			local s = Instance.new("BallSocketConstraint")
			s.Attachment0 = a0
			s.Attachment1 = a1
			s.LimitsEnabled = true
			s.UpperAngle = 50
			s.TwistLimitsEnabled = true
			s.TwistLowerAngle = -40
			s.TwistUpperAngle = 40
			s.Enabled = false
			s.Parent = d.Parent
			table.insert(info.motors, d)
			table.insert(info.sockets, s)
			info.limbs[d.Part1] = d.Part1.CanCollide
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Characters"
		end
	end)
	hum.Died:Connect(function()
		releaseHeld(player)
	end)
	charInfo[player] = info
	ragdolled[player] = nil
	resetting[player] = nil
	completed[player] = nil
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
	player.CharacterRemoving:Connect(function()
		releaseHeld(player)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	releaseHeld(player)
	charInfo[player], ragdolled[player], lastRagdoll[player], resetting[player], lastSlap[player], completed[player] = nil, nil, nil, nil, nil, nil
end)

---------------------------------------------------------------- grab / release / throw
GrabRemote.OnServerEvent:Connect(function(player, prop)
	if typeof(prop) ~= "Instance" or not prop:IsA("BasePart") or not CollectionService:HasTag(prop, "Grabbable") or not prop:IsDescendantOf(workspace) then
		return
	end
	if ragdolled[player] or resetting[player] or held[player] or prop:GetAttribute("HeldBy") then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) or hum.Health <= 0 then
		return
	end
	local offset = prop.Position - hrp.Position
	if math.abs(offset.Z) > 3 or offset.Magnitude > prop.Size.X / 2 + Config.GRAB_RANGE + 3 then
		return
	end
	local hold = Instance.new("Attachment")
	hold.Name = "HoldPoint"
	hold.Position = Vector3.new(0, Config.HOLD_HEIGHT, -(prop.Size.X / 2 + Config.HOLD_GAP))
	hold.Parent = hrp
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	grip.Parent = prop
	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = grip
	ap.Attachment1 = hold
	ap.MaxForce = 40000
	ap.Responsiveness = 40
	ap.MaxVelocity = 80
	ap.Parent = prop
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = grip
	ao.Attachment1 = hold
	ao.MaxTorque = 20000
	ao.Responsiveness = 30
	ao.Parent = prop
	prop.CollisionGroup = "HeldProps"
	prop:SetAttribute("HeldBy", player.UserId)
	pcall(function()
		prop:SetNetworkOwner(player)
	end)
	held[player] = { prop = prop, hold = hold, grip = grip, ap = ap, ao = ao }
	playAt(prop.Position, prop:GetAttribute("PropMaterial") == "Cardboard" and "CardboardRub" or "Fabric", 0.35)
end)

ReleaseRemote.OnServerEvent:Connect(function(player)
	releaseHeld(player)
end)
ForceRelease.Event:Connect(function(player)
	releaseHeld(player)
end)

ThrowRemote.OnServerEvent:Connect(function(player)
	local h = held[player]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (h and hrp) then
		return
	end
	local dir = hrp.CFrame.LookVector.X >= 0 and 1 or -1
	local prop = h.prop
	local scale = math.clamp(1.15 - prop.AssemblyMass / 60, 0.7, 1.1)
	local vel = Vector3.new(dir * Config.THROW_SPEED * scale + hrp.AssemblyLinearVelocity.X * 0.3, Config.THROW_UP * scale, 0)
	prop:SetAttribute("ThrownBy", player.UserId)
	prop:SetAttribute("ThrownAt", os.clock())
	releaseHeld(player, vel)
	playAt(prop.Position, "Whoosh", 0.45, 1.1 + math.random() * 0.15)
end)

---------------------------------------------------------------- slap
local musicBoxBusy = false
local function playMusicBox(box)
	if musicBoxBusy then
		return
	end
	musicBoxBusy = true
	playAt(box.Position, "WoodKnock", 0.5)
	local s = playAt(box.Position + Vector3.new(0, 1, 0), "MusicBox", 0.7, 1, 12)
	local dancer = box.Parent:FindFirstChild("FeltDancer")
	if dancer then
		local base = dancer.CFrame
		local spin = Instance.new("NumberValue")
		spin.Changed:Connect(function(v)
			dancer.CFrame = base * CFrame.Angles(0, v, 0)
		end)
		TweenService:Create(spin, TweenInfo.new(9, Enum.EasingStyle.Linear), { Value = math.pi * 12 }):Play()
		Debris:AddItem(spin, 10)
	end
	task.delay(9, function()
		if s and s.Parent then
			TweenService:Create(s, TweenInfo.new(1.5), { Volume = 0 }):Play()
		end
		task.wait(2)
		musicBoxBusy = false
	end)
end

local slapParams = OverlapParams.new()
slapParams.FilterType = Enum.RaycastFilterType.Exclude
SlapRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastSlap[player] and now - lastSlap[player] < Config.SLAP_COOLDOWN - 0.05 then
		return
	end
	lastSlap[player] = now
	if ragdolled[player] or held[player] or resetting[player] then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local dir = hrp.CFrame.LookVector.X >= 0 and 1 or -1
	slapParams.FilterDescendantsInstances = { char }
	local center = hrp.Position + Vector3.new(dir * (Config.SLAP_RANGE / 2 + 0.6), 0.4, 0)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(Config.SLAP_RANGE, 4.6, 5), slapParams)
	local hitProps, hitBeetle, hitBox, hitOther = {}, false, nil, {}
	for _, p in ipairs(parts) do
		if CollectionService:HasTag(p, "Prop") and not p.Anchored and not p:GetAttribute("HeldBy") then
			hitProps[p] = true
		elseif p:IsDescendantOf(boss) then
			hitBeetle = true
		elseif CollectionService:HasTag(p, "MusicBox") then
			hitBox = p
		elseif CollectionService:HasTag(p, "Slappable") then
			hitOther[p] = true
		end
	end
	local any = false
	for p in pairs(hitProps) do
		any = true
		local m = p.AssemblyMass
		p:ApplyImpulse(Vector3.new(dir * Config.SLAP_SPEED, Config.SLAP_UP, 0) * m)
		p:ApplyAngularImpulse(Vector3.new(0, 0, -dir * 0.8) * m)
		playAt(p.Position, p:GetAttribute("PropMaterial") or "Cardboard", 0.55)
	end
	if hitBeetle then
		any = true
		BeetleSlapped:Fire(player, dir)
	end
	if hitBox then
		any = true
		playMusicBox(hitBox)
	end
	for p in pairs(hitOther) do
		any = true
		if not p.Anchored then
			p:ApplyImpulse(Vector3.new(dir * Config.SLAP_SPEED * 0.6, Config.SLAP_UP * 0.4, 0) * p.AssemblyMass)
		end
		Slapped:Fire(p, player, dir)
	end
	playAt(center, "Slap", any and 0.7 or 0.2, any and 1 or 1.35)
end)

---------------------------------------------------------------- ragdoll + reset requests
ImpactRemote.OnServerEvent:Connect(function(player)
	if ragdolled[player] or resetting[player] then
		return
	end
	if lastRagdoll[player] and os.clock() - lastRagdoll[player] < Config.RAGDOLL_DURATION + Config.RAGDOLL_COOLDOWN then
		return
	end
	setRagdoll(player, true, Config.RAGDOLL_DURATION)
end)

RagdollRequest.Event:Connect(function(player, duration, knock)
	if ragdolled[player] or resetting[player] then
		return
	end
	setRagdoll(player, true, duration or Config.RAGDOLL_DURATION, knock)
end)

ResetRemote.OnServerEvent:Connect(function(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or resetting[player] then
		return
	end
	playAt(hrp.Position, "WindUp", 0.8, 1.7)
	paperBurst(hrp.Position + Vector3.new(0, 1, 0), 22)
	setRagdoll(player, true, nil, Vector3.new(0, 38, 0))
	respawn(player, Config.SELF_DESTRUCT_TIME)
end)

---------------------------------------------------------------- props: lane lock, fall reset, impact sounds
local props = {}
for _, p in ipairs(CollectionService:GetTagged("Prop")) do
	if p:IsDescendantOf(workspace) then
		table.insert(props, p)
		pcall(function()
			p:SetNetworkOwner(nil)
		end)
	end
end

local function resetProp(p)
	p.AssemblyLinearVelocity = Vector3.zero
	p.AssemblyAngularVelocity = Vector3.zero
	p.CFrame = p:GetAttribute("Home")
	p:SetAttribute("ThrownBy", nil)
end

local propVelocity = {} -- previous-frame velocity per prop (Touched fires after the bounce)
RunService.Heartbeat:Connect(function()
	for _, p in ipairs(props) do
		propVelocity[p] = p.AssemblyLinearVelocity
		if p.Parent and not p:GetAttribute("HeldBy") then
			local pos = p.Position
			if pos.Y < Config.PROP_RESET_Y then
				resetProp(p)
			else
				-- keep free props in their lane and rotating only within the play plane
				local lz = laneZ(pos.Z)
				local cf = p.CFrame
				if math.abs(pos.Z - lz) > 0.05 or math.abs(cf.LookVector.Z) < 0.999 then
					local rv = cf.RightVector
					p.CFrame = CFrame.new(pos.X, pos.Y, lz) * CFrame.Angles(0, 0, math.atan2(rv.Y, rv.X))
				end
				local v, av = p.AssemblyLinearVelocity, p.AssemblyAngularVelocity
				if math.abs(v.Z) > 0.01 then
					p.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
				end
				if math.abs(av.X) > 0.01 or math.abs(av.Y) > 0.01 then
					p.AssemblyAngularVelocity = Vector3.new(0, 0, av.Z)
				end
			end
		end
	end
end)

for _, p in ipairs(props) do
	local last = 0
	p.Touched:Connect(function(other)
		if other:IsDescendantOf(p) then
			return
		end
		local pv = propVelocity[p] or p.AssemblyLinearVelocity
		local rel = (pv - other.AssemblyLinearVelocity).Magnitude
		local now = os.clock()
		if rel > Config.IMPACT_SOUND_SPEED and now - last > Config.IMPACT_SOUND_COOLDOWN then
			last = now
			playAt(p.Position, p:GetAttribute("PropMaterial") or "Cardboard", math.clamp(rel / 40, 0.2, 0.9))
		end
		if pv.Magnitude > Config.RAGDOLL_PROP_SPEED and (other.Position - p.Position):Dot(pv) > 0 and not p:GetAttribute("HeldBy") then
			local model = other:FindFirstAncestorOfClass("Model")
			local victim = model and Players:GetPlayerFromCharacter(model)
			if victim then
				local selfHit = p:GetAttribute("ThrownBy") == victim.UserId and now - (p:GetAttribute("ThrownAt") or 0) < 0.5
				if not selfHit then
					setRagdoll(victim, true, Config.RAGDOLL_DURATION, Vector3.new(pv.X * 0.5, 14, 0))
				end
			end
		end
	end)
end

---------------------------------------------------------------- pop-up book (secret)
local popTrigger = triggers:WaitForChild("PopUpTrigger")
local popModel = map:WaitForChild("GameplayGeometry"):WaitForChild("F_ElevatedRoute"):WaitForChild("PopUp")
local flatAngle = popModel:GetAttribute("FlatAngle") or 89
local popBase = popModel.PrimaryPart.CFrame * CFrame.Angles(math.rad(-flatAngle), 0, 0)
local popAngle = Instance.new("NumberValue")
popAngle.Value = flatAngle
popAngle.Changed:Connect(function(v)
	popModel:PivotTo(popBase * CFrame.Angles(math.rad(v), 0, 0))
end)
local popUp, lastOnBook = false, 0
local function updatePopUp(anyoneOnBook)
	local now = os.clock()
	if anyoneOnBook then
		lastOnBook = now
		if not popUp then
			popUp = true
			playAt(popTrigger.Position, "PopUp", 0.6, 1.2)
			TweenService:Create(popAngle, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 }):Play()
		end
	elseif popUp and now - lastOnBook > 2.5 then
		popUp = false
		TweenService:Create(popAngle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = flatAngle }):Play()
	end
end

---------------------------------------------------------------- the finish
local goal = triggers:WaitForChild("Goal")
local function celebrate()
	playAt(goal.Position, "MusicBox", 0.9, 1.05, 10)
	paperBurst(goal.Position + Vector3.new(0, 4, 0), 30)
	for _, pen in ipairs(CollectionService:GetTagged("Pennant")) do
		local c = pen.CFrame
		local swing = CFrame.new(c.Position) * CFrame.Angles(math.rad(28), 0, 0) * c.Rotation
		TweenService:Create(pen, TweenInfo.new(0.22 + math.random() * 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true), { CFrame = swing }):Play()
	end
end

---------------------------------------------------------------- watchdog: falls, goal, pop-up
task.spawn(function()
	while true do
		task.wait(0.2)
		local onBook = false
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local pos = hrp.Position
				if pos.Y < Areas.get(player:GetAttribute("Area")).killY and not resetting[player] then
					respawn(player, Config.RESPAWN_DELAY)
				end
				if not completed[player] and isInside(goal, pos) then
					completed[player] = true
					celebrate()
				end
				if isInside(popTrigger, pos) then
					onBook = true
				end
			end
		end
		updatePopUp(onBook)
	end
end)
