-- LevelRuntime: the shared level pieces every area uses, driven by CollectionService tags.
--   Mover       moving geometry (see ReplicatedStorage.PaperWorkshop.Motion); the server moves it for props
--   Checkpoint  volume: Spawn (spawn part name), Order (only ever moves you forward), Marker (ObjectValue child, optional)
--   KillVolume  volume: falling in sends you back to your checkpoint
--   Hazard      part: touching it knocks you over. Power, Up, Lethal (you pop and respawn instead)
--   Plate       part: Pressed while a player or a heavy loose thing rests on it. MinMass (default 6)
--   Keepsake    model/part: Id, Title, Note. Picking it up sets Flag_Keep_<Id> and shows its note card
-- Critters report stomps and hits from the client (the client knows exactly where its character is);
-- the server sanity-checks distance and hands the stomp to the critter's own script.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("PaperWorkshop")
local Motion = require(Shared:WaitForChild("Motion"))
local Remotes = Shared:WaitForChild("Remotes")
local Travel = require(script.Parent:WaitForChild("Travel"))
local Util = require(script.Parent:WaitForChild("Util"))
local RagdollRequest = script.Parent:WaitForChild("RagdollRequest")

local function remote(name)
	local r = Remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local BounceRemote = remote("Bounce") -- server -> client: (upSpeed, sideSpeed)
local NoteRemote = remote("KeepsakeNote") -- server -> client: (id, title, note)
local StompRemote = remote("Stomp") -- client -> server: (critterModel)
local HurtRemote = remote("Hurt") -- client -> server: (critterModel or hazard part)

local function bindable(name)
	local b = script.Parent:FindFirstChild(name) or Instance.new("BindableEvent")
	b.Name = name
	b.Parent = script.Parent
	return b
end
local CritterStomped = bindable("CritterStomped") -- (model, player)
local CheckpointReached = bindable("CheckpointReached") -- (player, checkpointPart)

local function hrpOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function tagged(tag)
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsDescendantOf(workspace) then
			table.insert(list, inst)
		end
	end
	return list
end

-- a live list per tag, kept current as things are tagged/untagged at runtime
local live = {}
local function watch(tag)
	live[tag] = tagged(tag)
	local function refresh()
		live[tag] = tagged(tag)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(refresh)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(refresh)
end
for _, t in ipairs({ "Mover", "Checkpoint", "KillVolume", "Hazard", "Plate", "Keepsake" }) do
	watch(t)
end

---------------------------------------------------------------- movers (server copy, for props and hazards)
RunService.Heartbeat:Connect(function()
	local t = Motion.now()
	for _, m in ipairs(live.Mover) do
		Motion.apply(m, t)
	end
end)

---------------------------------------------------------------- respawn helper
local resetting = {}
local function sendBack(player, soundKey, delay)
	if resetting[player] then
		return
	end
	resetting[player] = true
	local hrp = hrpOf(player)
	if hrp and soundKey then
		Util.playAt(hrp.Position, soundKey, 0.7)
	end
	task.delay(delay or 0.6, function()
		resetting[player] = nil
		if player.Parent and not Travel.isTravelling(player) then
			player:LoadCharacter()
		end
	end)
end

-- a real hit: you burst into paper scraps and come back at your checkpoint
local SCRAPS = { Color3.fromRGB(196, 152, 104), Color3.fromRGB(240, 230, 206), Color3.fromRGB(186, 64, 50), Color3.fromRGB(84, 136, 134), Color3.fromRGB(212, 166, 68) }
local function pop(player)
	if resetting[player] then
		return
	end
	local char = player.Character
	local hrp = hrpOf(player)
	if not (char and hrp) then
		sendBack(player)
		return
	end
	local pos = hrp.Position
	Util.playAt(pos, "PopUp", 0.9, 0.75)
	Util.playAt(pos, "PaperRustle", 0.8, 1.3)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	hrp.Anchored = true
	for _ = 1, 18 do
		local s = Instance.new("Part")
		s.Name = "PopScrap"
		s.Size = Vector3.new(0.25 + math.random() * 0.5, 0.05, 0.25 + math.random() * 0.45)
		s.Color = SCRAPS[math.random(#SCRAPS)]
		s.Material = Enum.Material.SmoothPlastic
		s.CanTouch, s.CanQuery = false, false
		s.CFrame = CFrame.new(pos + Vector3.new(math.random() - 0.5, math.random() * 2 - 0.5, (math.random() - 0.5) * 0.6)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		s.Parent = workspace
		s.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 30, 14 + math.random() * 18, (math.random() - 0.5) * 6)
		s.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
		Debris:AddItem(s, 2.2)
	end
	sendBack(player, nil, 1)
end

---------------------------------------------------------------- checkpoints
local function cpKey(player)
	return "CPOrder_" .. Travel.area(player)
end
local function watchPlayer(player)
	player:GetAttributeChangedSignal("Area"):Connect(function()
		player:SetAttribute(cpKey(player), 0) -- arriving somewhere starts its checkpoints over
	end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end

local function lightMarker(cp)
	local ref = cp:FindFirstChild("Marker")
	local marker = ref and ref.Value
	if marker and not marker:GetAttribute("Lit") then
		marker:SetAttribute("Lit", true)
		Util.playAt(marker:GetPivot().Position, "GlassTink", 0.4, 1.25)
		Util.playAt(marker:GetPivot().Position, "PaperRustle", 0.35, 1.1)
	end
end

---------------------------------------------------------------- hazards
local hazardParams = OverlapParams.new()
hazardParams.FilterType = Enum.RaycastFilterType.Include
local lastHurt = {}
local function hurt(player, from: Vector3, power, up, lethal)
	local now = os.clock()
	if lastHurt[player] and now - lastHurt[player] < 1.4 then
		return
	end
	lastHurt[player] = now
	local hrp = hrpOf(player)
	if not hrp then
		return
	end
	if lethal then
		pop(player)
		return
	end
	local dir = (hrp.Position.X >= from.X) and 1 or -1
	Util.playAt(hrp.Position, "Cardboard", 0.6, 0.85)
	RagdollRequest:Fire(player, nil, Vector3.new(dir * (power or 20), up or 22, 0))
end

---------------------------------------------------------------- critter reports from clients
StompRemote.OnServerEvent:Connect(function(player, model)
	if typeof(model) ~= "Instance" or not CollectionService:HasTag(model, "Critter") then
		return
	end
	local hrp = hrpOf(player)
	if not hrp or model:GetAttribute("Stunned") then
		return
	end
	if (model:GetPivot().Position - hrp.Position).Magnitude > 12 then
		return
	end
	CritterStomped:Fire(model, player)
end)

HurtRemote.OnServerEvent:Connect(function(player, source)
	if typeof(source) ~= "Instance" then
		return
	end
	local hrp = hrpOf(player)
	if not hrp then
		return
	end
	if CollectionService:HasTag(source, "Critter") then
		if source:GetAttribute("Stunned") or source:GetAttribute("Harmless") then
			return
		end
		local pos = source:GetPivot().Position
		if (pos - hrp.Position).Magnitude > 14 then
			return
		end
		hurt(player, pos, source:GetAttribute("Power") or 20, source:GetAttribute("Up") or 20, source:GetAttribute("Lethal"))
	end
end)

---------------------------------------------------------------- plates
local plateParams = OverlapParams.new()
plateParams.FilterType = Enum.RaycastFilterType.Exclude
local function platePressed(plate)
	local minMass = plate:GetAttribute("MinMass") or 6
	local box = plate.CFrame * CFrame.new(0, plate.Size.Y / 2 + 1.6, 0)
	local size = Vector3.new(plate.Size.X - 0.2, 3, plate.Size.Z - 0.2)
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = hrpOf(p)
		if hrp and plate:GetAttribute("PlayersCount") ~= false then
			local rel = box:PointToObjectSpace(hrp.Position - Vector3.new(0, 2.4, 0))
			if math.abs(rel.X) <= size.X / 2 + 0.6 and math.abs(rel.Y) <= 2 and math.abs(rel.Z) <= size.Z / 2 + 0.6 then
				return true
			end
		end
	end
	plateParams.FilterDescendantsInstances = { plate }
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, size, plateParams)) do
		if not part.Anchored and part.AssemblyMass >= minMass then
			return true
		end
	end
	return false
end

local plateHome = {}
local function setPlate(plate, pressed)
	if (plate:GetAttribute("Pressed") == true) == pressed then
		return
	end
	plate:SetAttribute("Pressed", pressed)
	plateHome[plate] = plateHome[plate] or plate.CFrame
	local home = plateHome[plate]
	local sink = plate:GetAttribute("Sink") or 0.3
	TweenService:Create(plate, TweenInfo.new(0.15), { CFrame = pressed and (home - Vector3.new(0, sink, 0)) or home }):Play()
	Util.playAt(plate.Position, pressed and "WoodKnock" or "GearClick", 0.35, pressed and 0.9 or 1.3)
end

---------------------------------------------------------------- the slow loop: checkpoints, kill volumes, hazards, plates, keepsakes
task.spawn(function()
	while true do
		task.wait(0.08)
		hazardParams.FilterDescendantsInstances = live.Hazard
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp = hrpOf(player)
			if hrp and not resetting[player] and not Travel.isTravelling(player) then
				local pos = hrp.Position
				local area = Travel.area(player)
				-- checkpoints only ever move you forward within an area
				for _, cp in ipairs(live.Checkpoint) do
					if Util.isInside(cp, pos) then
						local order = cp:GetAttribute("Order") or 0
						if (cp:GetAttribute("Area") or area) == area and order > (player:GetAttribute(cpKey(player)) or 0) then
							player:SetAttribute(cpKey(player), order)
							Travel.setCheckpoint(player, cp:GetAttribute("Spawn"))
							lightMarker(cp)
							CheckpointReached:Fire(player, cp)
						end
					end
				end
				for _, kv in ipairs(live.KillVolume) do
					if Util.isInside(kv, pos) then
						sendBack(player, kv:GetAttribute("Sound"))
						break
					end
				end
				if #live.Hazard > 0 then
					local hits = workspace:GetPartBoundsInBox(hrp.CFrame * CFrame.new(0, -0.5, 0), Vector3.new(2, 4.8, 1.4), hazardParams)
					local h = hits[1]
					if h and h:GetAttribute("Armed") ~= false then
						hurt(player, h.Position, h:GetAttribute("Power"), h:GetAttribute("Up"), h:GetAttribute("Lethal"))
					end
				end
				for _, k in ipairs(live.Keepsake) do
					local id = k:GetAttribute("Id")
					if id and not Travel.flag(player, "Keep_" .. id) then
						local kp = k:IsA("Model") and k:GetPivot().Position or k.Position
						if (kp - pos).Magnitude < 3.6 then
							Travel.setFlag(player, "Keep_" .. id)
							Util.playAt(kp, "MusicBox", 0.35, 1.5, 3)
							Util.playAt(kp, "PaperRustle", 0.5)
							NoteRemote:FireClient(player, id, k:GetAttribute("Title"), k:GetAttribute("Note"))
						end
					end
				end
			end
		end
		for _, plate in ipairs(live.Plate) do
			setPlate(plate, platePressed(plate))
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	resetting[player], lastHurt[player] = nil, nil
end)

-- for level scripts: shove a player into the air (springs, stomps, pop-up toys)
local Launch = bindable("Launch") -- (player, upSpeed, sideSpeed)
Launch.Event:Connect(function(player, up, side)
	BounceRemote:FireClient(player, up, side or 0)
end)
local Hurt = bindable("HurtPlayer") -- (player, fromPosition, power, up, lethal)
Hurt.Event:Connect(hurt)
local SendBack = bindable("SendBack") -- (player, soundKey)
SendBack.Event:Connect(sendBack)
local Pop = bindable("Pop") -- (player)
Pop.Event:Connect(pop)
