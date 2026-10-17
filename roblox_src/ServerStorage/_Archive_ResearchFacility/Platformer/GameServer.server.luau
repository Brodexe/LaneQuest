-- GameServer: players, checkpoints, collectibles, hazards, exit, crates, progression + unlocks.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Platformer")
local Config = require(Shared:WaitForChild("Config"))

-- Remotes ------------------------------------------------------------------
local Remotes = Shared:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = Shared
local function remote(name, class)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(class or "RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end
local GrabCrate = remote("GrabCrate")
local ResetCrates = remote("ResetCrates")
local Collected = remote("Collected")
local LevelComplete = remote("LevelComplete")
local Notify = remote("Notify")
local SetCostume = remote("SetCostume")
local Replay = remote("Replay")
local ProfileUpdate = remote("ProfileUpdate")
remote("SwingSync", "UnreliableRemoteEvent")

local level = workspace:WaitForChild("ResearchFacility")
local TOTAL_SECRETS = level:GetAttribute("Secrets") or 0
local TOTAL_COLLECTIBLES = level:GetAttribute("Collectibles") or 0

-- Data ---------------------------------------------------------------------
local store
pcall(function()
	store = DataStoreService:GetDataStore("ResearchFacility_v1")
end)

local state = {} -- per-run state
local profiles = {} -- persistent progression

local function defaultProfile()
	return { best = 0, completed = false, secrets = {}, costume = "LabCoat", bestTime = nil }
end

local function countSecrets(p)
	local n = 0
	for _ in pairs(p.secrets) do
		n += 1
	end
	return n
end

local function isUnlocked(p, costume)
	local r = costume.req
	if r.score and p.best < r.score then
		return false
	end
	if r.completed and not p.completed then
		return false
	end
	if r.secrets == "all" and countSecrets(p) < TOTAL_SECRETS then
		return false
	end
	return true
end

local function costumeById(id)
	for _, c in ipairs(Config.COSTUMES) do
		if c.id == id then
			return c
		end
	end
end

local function sendProfile(player)
	local p = profiles[player]
	if not p then
		return
	end
	local unlocked = {}
	for _, c in ipairs(Config.COSTUMES) do
		if isUnlocked(p, c) then
			table.insert(unlocked, c.id)
		end
	end
	ProfileUpdate:FireClient(player, {
		best = p.best,
		bestTime = p.bestTime,
		completed = p.completed,
		secretsEver = countSecrets(p),
		totalSecrets = TOTAL_SECRETS,
		totalCollectibles = TOTAL_COLLECTIBLES,
		unlocked = unlocked,
		costume = p.costume,
	})
end

local function saveProfile(player)
	local p = profiles[player]
	if not (p and store) then
		return
	end
	pcall(function()
		store:SetAsync("u" .. player.UserId, p)
	end)
end

-- Costumes -----------------------------------------------------------------
local function applyCostume(player)
	local char = player.Character
	local p = profiles[player]
	if not (char and p) then
		return
	end
	local c = costumeById(p.costume) or Config.COSTUMES[1]
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestorWhichIsA("Accessory") then
			if d.Name ~= "Head" then
				d.Color = c.color
				d.Material = c.material
			end
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local old = hrp:FindFirstChild("CostumeTrail")
		if old then
			old:Destroy()
		end
		if c.trail then
			local a0 = hrp:FindFirstChild("TrailA") or Instance.new("Attachment")
			a0.Name = "TrailA"
			a0.Position = Vector3.new(0, 0.9, 0)
			a0.Parent = hrp
			local a1 = hrp:FindFirstChild("TrailB") or Instance.new("Attachment")
			a1.Name = "TrailB"
			a1.Position = Vector3.new(0, -0.9, 0)
			a1.Parent = hrp
			local t = Instance.new("Trail")
			t.Name = "CostumeTrail"
			t.Attachment0 = a0
			t.Attachment1 = a1
			t.Color = ColorSequence.new(c.trail)
			t.Transparency = NumberSequence.new(0.2, 1)
			t.Lifetime = 0.35
			t.LightEmission = 0.8
			t.Parent = hrp
		end
	end
end

SetCostume.OnServerEvent:Connect(function(player, id)
	local p = profiles[player]
	local c = costumeById(id)
	if p and c and isUnlocked(p, c) then
		p.costume = id
		applyCostume(player)
		sendProfile(player)
	end
end)

-- Checkpoints --------------------------------------------------------------
local checkpoints = {}
for _, cp in ipairs(CollectionService:GetTagged("Checkpoint")) do
	if cp:IsDescendantOf(level) then
		checkpoints[cp:GetAttribute("Order")] = cp
	end
end

local function playerFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(model), model, hum
end

for order, cp in pairs(checkpoints) do
	local trig = cp:FindFirstChild("Trigger")
	local lamp = cp:FindFirstChild("Lamp")
	trig.Touched:Connect(function(hit)
		local player = playerFromPart(hit)
		local st = player and state[player]
		if st and order > st.checkpoint then
			st.checkpoint = order
			if lamp then
				lamp.Color = Color3.fromRGB(80, 255, 140)
			end
			if order > 0 then
				Notify:FireClient(player, "Checkpoint reached", Color3.fromRGB(80, 255, 140))
			end
		end
	end)
end

local function spawnCFrame(st)
	local cp = checkpoints[st.checkpoint] or checkpoints[0]
	local pos = cp.Position + Vector3.new(0, 3.4, 0)
	return CFrame.lookAt(pos, pos + Vector3.xAxis), cp:GetAttribute("Lane") or 1
end

-- Crates -------------------------------------------------------------------
local grabbed = {} -- player -> crate

local function releaseCrate(player)
	local crate = grabbed[player]
	grabbed[player] = nil
	if crate and crate.Parent then
		crate:SetAttribute("GrabbedBy", nil)
		if not crate.Anchored then
			pcall(function()
				crate:SetNetworkOwnershipAuto()
			end)
		end
	end
end

GrabCrate.OnServerEvent:Connect(function(player, crate, on)
	if on then
		if typeof(crate) ~= "Instance" or not CollectionService:HasTag(crate, "Crate") then
			return
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - crate.Position).Magnitude > 14 then
			return
		end
		local by = crate:GetAttribute("GrabbedBy")
		if by and by ~= player.UserId then
			return
		end
		releaseCrate(player)
		grabbed[player] = crate
		crate:SetAttribute("GrabbedBy", player.UserId)
		pcall(function()
			crate:SetNetworkOwner(player)
		end)
	else
		releaseCrate(player)
	end
end)

local function resetCrate(crate)
	local home = crate:GetAttribute("Home")
	if not home then
		return
	end
	for p, c in pairs(grabbed) do
		if c == crate then
			releaseCrate(p)
		end
	end
	crate.AssemblyLinearVelocity = Vector3.zero
	crate.AssemblyAngularVelocity = Vector3.zero
	crate.CFrame = CFrame.new(home)
end

local lastReset = {}
ResetCrates.OnServerEvent:Connect(function(player)
	if lastReset[player] and os.clock() - lastReset[player] < 3 then
		return
	end
	lastReset[player] = os.clock()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local n = 0
	for _, crate in ipairs(CollectionService:GetTagged("Crate")) do
		local home = crate:GetAttribute("Home")
		if home and (home - hrp.Position).Magnitude < 90 then
			resetCrate(crate)
			n += 1
		end
	end
	Notify:FireClient(player, n > 0 and "Nearby crates reset" or "No crates nearby", Color3.fromRGB(255, 220, 120))
end)

-- Collectibles -------------------------------------------------------------
local function setScore(player, st)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Score.Value = st.score
		ls.Secrets.Value = st.secrets
	end
	player:SetAttribute("Score", st.score)
	player:SetAttribute("SecretsFound", st.secrets)
end

for _, c in ipairs(CollectionService:GetTagged("Collectible")) do
	if c:IsDescendantOf(level) then
		c.Touched:Connect(function(hit)
			local player = playerFromPart(hit)
			local st = player and state[player]
			if not st or st.finished then
				return
			end
			local id = c:GetAttribute("Id")
			if st.collected[id] then
				return
			end
			st.collected[id] = true
			st.score += c:GetAttribute("Value") or 0
			local secret = c:GetAttribute("Secret") == true
			if secret then
				st.secrets += 1
				local p = profiles[player]
				if p then
					p.secrets[id] = true
				end
			end
			setScore(player, st)
			Collected:FireClient(player, c, secret)
		end)
	end
end

-- Hazards ------------------------------------------------------------------
local function kill(hum)
	if hum and hum.Health > 0 then
		hum.Health = 0
	end
end

local hazards = {}
for _, h in ipairs(CollectionService:GetTagged("Hazard")) do
	if h:IsDescendantOf(level) then
		table.insert(hazards, h)
		h.Touched:Connect(function(hit)
			if h:GetAttribute("Active") == false then
				return
			end
			local player, _, hum = playerFromPart(hit)
			if player then
				kill(hum)
			end
		end)
	end
end

-- Robust overlap check (catches players already standing inside a hazard when it switches on)
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
task.spawn(function()
	while true do
		task.wait(0.1)
		local chars = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(chars, p.Character)
			end
		end
		if #chars > 0 then
			overlap.FilterDescendantsInstances = chars
			for _, h in ipairs(hazards) do
				if h:GetAttribute("Active") ~= false then
					for _, part in ipairs(workspace:GetPartsInPart(h, overlap)) do
						local _, _, hum = playerFromPart(part)
						kill(hum)
					end
				end
			end
			-- fell out of the world
			for _, ch in ipairs(chars) do
				local hrp = ch:FindFirstChild("HumanoidRootPart")
				if hrp and hrp.Position.Y < -40 then
					kill(ch:FindFirstChildOfClass("Humanoid"))
				end
			end
		end
		-- crates that fell into a pit return home
		for _, crate in ipairs(CollectionService:GetTagged("Crate")) do
			local home = crate:GetAttribute("Home")
			if home and crate.Position.Y < -10 then
				resetCrate(crate)
			end
		end
	end
end)

-- Exit ---------------------------------------------------------------------
local function finishLevel(player)
	local st = state[player]
	if not st or st.finished then
		return
	end
	st.finished = true
	local p = profiles[player]
	local elapsed = os.clock() - st.startTime
	local before = {}
	for _, c in ipairs(Config.COSTUMES) do
		before[c.id] = isUnlocked(p, c)
	end
	p.completed = true
	p.best = math.max(p.best, st.score)
	if not p.bestTime or elapsed < p.bestTime then
		p.bestTime = elapsed
	end
	local newly = {}
	for _, c in ipairs(Config.COSTUMES) do
		if isUnlocked(p, c) and not before[c.id] then
			table.insert(newly, c.name)
		end
	end
	LevelComplete:FireClient(player, {
		score = st.score,
		secrets = st.secrets,
		totalSecrets = TOTAL_SECRETS,
		collected = (function()
			local n = 0
			for _ in pairs(st.collected) do
				n += 1
			end
			return n
		end)(),
		totalCollectibles = TOTAL_COLLECTIBLES,
		time = elapsed,
		bestTime = p.bestTime,
		best = p.best,
		unlocked = newly,
	})
	sendProfile(player)
	saveProfile(player)
end

for _, ex in ipairs(CollectionService:GetTagged("Exit")) do
	if ex:IsDescendantOf(level) then
		ex:FindFirstChild("Trigger").Touched:Connect(function(hit)
			local player = playerFromPart(hit)
			if player then
				finishLevel(player)
			end
		end)
	end
end

local function newRun(player)
	state[player] = { checkpoint = 0, collected = {}, score = 0, secrets = 0, startTime = os.clock(), finished = false }
	setScore(player, state[player])
end

Replay.OnServerEvent:Connect(function(player)
	local st = state[player]
	if st and st.finished then
		newRun(player)
		player:LoadCharacter()
	end
end)

-- Players ------------------------------------------------------------------
local function onCharacter(player, char)
	local st = state[player]
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	local hum = char:WaitForChild("Humanoid", 10)
	if not (hrp and hum and st) then
		return
	end
	local cf, lane = spawnCFrame(st)
	player:SetAttribute("SpawnLane", lane)
	char:PivotTo(cf)
	hum.Died:Connect(function()
		releaseCrate(player)
	end)
	if player:HasAppearanceLoaded() then
		applyCostume(player)
	end
end

local function onPlayer(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local s = Instance.new("IntValue")
	s.Name = "Score"
	s.Parent = ls
	local g = Instance.new("IntValue")
	g.Name = "Secrets"
	g.Parent = ls
	ls.Parent = player

	local p = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				p[k] = v
			end
			p.secrets = p.secrets or {}
		end
	end
	profiles[player] = p
	newRun(player)

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	player.CharacterAppearanceLoaded:Connect(function()
		applyCostume(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	task.delay(1, sendProfile, player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

Players.PlayerRemoving:Connect(function(player)
	releaseCrate(player)
	saveProfile(player)
	state[player] = nil
	profiles[player] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		saveProfile(p)
	end
end)
