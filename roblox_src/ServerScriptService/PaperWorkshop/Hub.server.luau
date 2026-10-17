-- Hub: the Loomworks. The Heartloom's reactions, the Archive cabinet, travel, the drawer secret and the small lives.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Travel = require(script.Parent:WaitForChild("Travel"))
local Util = require(script.Parent:WaitForChild("Util"))
local Areas = require(ReplicatedStorage:WaitForChild("PaperWorkshop"):WaitForChild("Areas"))
local Slapped = script.Parent:WaitForChild("Slapped")

local hub = workspace:WaitForChild("Loomworks")
local HL = hub:WaitForChild("Heartloom")
local mech = hub:WaitForChild("Mechanisms")
local triggers = hub:WaitForChild("Triggers")
local LOOM = Vector3.new(380, 28, -16)

---------------------------------------------------------------- Heartloom connections (one per entry in Areas.Connections)
local conns = {}
for _, c in ipairs(Areas.Connections) do
	local node = HL.Nodes:FindFirstChild("Node_" .. c.id)
	conns[c.id] = {
		slack = HL.Threads:FindFirstChild("Thread_" .. c.id),
		taut = HL.Threads:FindFirstChild("Thread_" .. c.id .. "_Taut"),
		bead = node and node:FindFirstChild("Lamp"),
		state = "dormant",
	}
end

local function fadeModel(model, to, time)
	if not model then
		return
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			TweenService:Create(p, TweenInfo.new(time), { Transparency = to }):Play()
		end
	end
end

local function setConnection(id, state)
	local c = conns[id]
	if not c or c.state == state then
		return
	end
	c.state = state
	hub:SetAttribute("Conn_" .. id, state)
	fadeModel(c.slack, state == "dormant" and 0 or 1, 0.8)
	fadeModel(c.taut, state == "dormant" and 1 or 0, 0.8)
	if c.bead then
		local light = c.bead:FindFirstChildOfClass("PointLight")
		local bright = state == "restored" and 1.8 or (state == "awake" and 0.7 or 0)
		task.spawn(function()
			for _, on in ipairs({ true, false, true, false, true }) do
				light.Brightness = on and bright or 0.1
				c.bead.Color = on and Color3.fromRGB(255, 220, 160) or Color3.fromRGB(120, 110, 96)
				task.wait(0.07 + math.random() * 0.06)
			end
		end)
	end
end

local function motif(volume)
	local s = Util.playAt(LOOM, "MusicBox", volume or 0.3, 1, 9)
	if s then
		task.delay(6.5, function()
			if s.Parent then
				TweenService:Create(s, TweenInfo.new(2), { Volume = 0 }):Play()
			end
		end)
	end
end

local function twitchInner()
	local inner = HL:FindFirstChild("InnerRing")
	if inner then
		inner:SetAttribute("Active", true)
		Util.playAt(LOOM, "GearClick", 0.5)
		task.delay(0.7, function()
			inner:SetAttribute("Active", false)
		end)
	end
end

-- the outer ring's fallen pieces lift back into the gap
local function reseat()
	local fallen = HL:FindFirstChild("FallenSegments")
	if not fallen then
		return
	end
	for k, seg in ipairs(fallen:GetChildren()) do
		local from, to = seg:GetAttribute("Lying"), seg:GetAttribute("Home")
		task.delay(k * 0.5, function()
			Util.playAt(seg.Position, "WoodKnock", 0.5, 1.1)
			Util.tweenValue(0, 1, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), function(a)
				local p = from.Position:Lerp(to.Position, a) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)
				seg.CFrame = CFrame.new(p) * from.Rotation:Lerp(to.Rotation, a)
			end)
		end)
	end
	local mid = HL:FindFirstChild("MiddleRing")
	if mid then
		mid:SetAttribute("Speed", 0.3)
	end
end

local function onArrive(player)
	if not Travel.flag(player, "HubArrived") then
		Travel.setFlag(player, "HubArrived")
		task.wait(1.4)
		Travel.cue(player, LOOM, 74, 4.2)
		task.wait(1.3)
		twitchInner()
		Util.playAt(LOOM, "GlassTink", 0.5, 0.9)
		setConnection("Archive", "awake")
		motif(0.32)
	elseif Travel.flag(player, "ArchiveComplete") and not Travel.flag(player, "LoomRestoredSeen") then
		Travel.setFlag(player, "LoomRestoredSeen")
		task.wait(1)
		Travel.cue(player, LOOM, 70, 4.6)
		task.wait(1)
		setConnection("Archive", "restored")
		reseat()
		motif(0.4)
	end
end

local function watchPlayer(player)
	player:GetAttributeChangedSignal("Area"):Connect(function()
		if player:GetAttribute("Area") == "Hub" then
			task.spawn(onArrive, player)
		end
	end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end

---------------------------------------------------------------- the Archive cabinet: pull the cord to open it
local door = mech:WaitForChild("CabinetDoor")
local waves = mech:WaitForChild("PaperWaves")
local toggle = mech:WaitForChild("PullToggle")
local cord = toggle:WaitForChild("Cord")
local anchor = cord.Attachment0
local miniLamp = hub.Geometry.Cabinet.Miniature:FindFirstChild("MiniLamp")
local cabinetOpen = false
local pullTime = 0

local function openCabinet()
	cabinetOpen = true
	hub:SetAttribute("CabinetOpen", true)
	Util.playAt(door:GetPivot().Position, "WoodCreak", 0.7)
	Util.playAt(door:GetPivot().Position, "Ratchet", 0.4, 0.8)
	Util.swingModel(door, CFrame.new(434, 16.6, -5), "Y", 0, -100, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	if miniLamp then
		local l = miniLamp:FindFirstChildOfClass("PointLight")
		task.delay(0.6, function()
			l.Brightness = 1.2
			miniLamp.Color = Color3.fromRGB(255, 220, 160)
			Util.playAt(miniLamp.Position, "GlassTink", 0.35, 1.3)
		end)
	end
	for _, w in ipairs(waves:GetChildren()) do
		local k = w:GetAttribute("Index") or 0
		local flat = w.CFrame
		local up = CFrame.new(flat.Position + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, math.rad(90), 0)
		task.delay(0.8 + k * 0.15, function()
			Util.playAt(w.Position, "PaperRustle", 0.25, 1.2)
			Util.tweenValue(0, 1, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), function(a)
				w.CFrame = flat:Lerp(up, a)
			end)
		end)
	end
	local c = conns.Archive
	if c and c.bead then
		Util.playAt(c.bead.Position, "GlassTink", 0.3, 1.1)
	end
end

RunService.Heartbeat:Connect(function(dt)
	if cabinetOpen then
		return
	end
	local holder = toggle:GetAttribute("HeldBy")
	local player = holder and Players:GetPlayerByUserId(holder)
	local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local taut = (toggle.Position - anchor.WorldPosition).Magnitude > cord.Length - 0.4
	if hrp and taut and hrp.Position.X < toggle.Position.X - 1.2 then
		pullTime += dt
		if pullTime > 0.3 and conns.Archive and conns.Archive.state ~= "dormant" then
			openCabinet()
		end
	else
		pullTime = math.max(0, pullTime - dt)
	end
end)

---------------------------------------------------------------- the dais drawer (a secret note)
local drawer = mech:WaitForChild("SecretDrawer")
local drawerOpen = false
Slapped.Event:Connect(function(part, player)
	if part.Name == "DrawerFront" and part:IsDescendantOf(drawer) and not drawerOpen then
		drawerOpen = true
		Travel.setFlag(player, "HubSecret")
		Util.playAt(part.Position, "WoodCreak", 0.6, 1.2)
		local from = drawer:GetPivot()
		Util.tweenModel(drawer, from, from + Vector3.new(0, 0, 1.9), TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		local note = drawer:FindFirstChild("MakersNote")
		task.delay(0.55, function()
			Util.playAt(note.Position, "PaperRustle", 0.4)
			local a = note.CFrame
			Util.tweenValue(0, 1, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), function(k)
				note.CFrame = a + Vector3.new(0, 1.6 * k, 0.4 * k)
			end)
		end)
	elseif part.Name == "PaperLantern" then
		Util.playAt(part.Position, "PaperRustle", 0.5, 1.3)
	end
end)

---------------------------------------------------------------- travel triggers
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, p in ipairs(Util.playersIn(triggers.ToDemo)) do
			if not Travel.isTravelling(p) then
				task.spawn(Travel.go, p, "Demo", "FromHub")
			end
		end
		if cabinetOpen then
			for _, p in ipairs(Util.playersIn(triggers.ToArchive)) do
				if not Travel.isTravelling(p) then
					task.spawn(Travel.go, p, "Archive", "Entry")
				end
			end
		end
	end
end)

---------------------------------------------------------------- small lives
local function anyoneInHub()
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Area") == "Hub" then
			return true
		end
	end
	return false
end

-- the little crane: lifts, stacks, wobbles, drops it, drags it back, tries again
task.spawn(function()
	local block = mech:WaitForChild("CraneBlock")
	local str = mech:WaitForChild("CraneString")
	local function setBlock(cf)
		block:PivotTo(cf)
		local p = cf.Position
		local top = 19.6
		str.Size = Vector3.new(0.06, math.max(0.1, top - (p.Y + 0.6)), 0.06)
		str.CFrame = CFrame.new(p.X, (top + p.Y + 0.6) / 2, p.Z)
	end
	local function move(a, b, t, style)
		Util.tweenValue(0, 1, TweenInfo.new(t, style or Enum.EasingStyle.Sine), function(k)
			setBlock(a:Lerp(b, k))
		end)
		task.wait(t)
	end
	local z = -6.5
	local pile = CFrame.new(358.5, 13.2, z)
	while true do
		local up = CFrame.new(358.5, 17.6, z)
		local over = CFrame.new(353.9, 17.6, z)
		local onTop = CFrame.new(353.9, 15.8, z)
		move(pile, up, 1.2)
		move(up, over, 1.4)
		move(over, onTop, 1)
		for _, d in ipairs({ 10, -12, 14 }) do
			move(onTop, onTop * CFrame.Angles(0, 0, math.rad(d)), 0.18)
			move(onTop * CFrame.Angles(0, 0, math.rad(d)), onTop, 0.18)
		end
		local fallen = CFrame.new(356.6, 13.2, z) * CFrame.Angles(0, 0, math.rad(-90))
		move(onTop, fallen, 0.45, Enum.EasingStyle.Quad)
		local nearest, d = Util.nearestPlayer(fallen.Position, 34)
		if nearest then
			Util.playAt(fallen.Position, "WoodKnock", 0.35, 1.5)
		end
		task.wait(1.2)
		move(fallen, pile, 1.6)
		task.wait(0.8)
	end
end)

-- the button snail: strolls, and hides in its button when you come close
task.spawn(function()
	local snail = mech:WaitForChild("ButtonSnail")
	local parts = {}
	for _, p in ipairs(snail:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name == "Body" or p.Name == "Antenna") then
			table.insert(parts, p)
		end
	end
	local x, dir = 400, 1
	local base = snail:GetPivot()
	local hiddenUntil = 0
	local last = os.clock()
	while true do
		task.wait(1 / 20)
		local now = os.clock()
		local dt = now - last
		last = now
		local pos = Vector3.new(x, base.Position.Y, base.Position.Z)
		local _, d = Util.nearestPlayer(pos, 5)
		if d < 5 and now > hiddenUntil then
			hiddenUntil = now + 3.2
			for _, p in ipairs(parts) do
				p.Transparency = 1
			end
		elseif now > hiddenUntil and parts[1].Transparency == 1 then
			for _, p in ipairs(parts) do
				p.Transparency = 0
			end
		end
		if now > hiddenUntil then
			x += dir * 0.8 * dt
			if x > 424 or x < 396 then
				dir = -dir
				x = math.clamp(x, 396, 424)
			end
		end
		local face = dir > 0 and CFrame.Angles(0, math.rad(180), 0) or CFrame.identity
		local bob = (now < hiddenUntil) and math.sin(now * 30) * 0.03 or math.abs(math.sin(now * 3)) * 0.05
		snail:PivotTo(CFrame.new(x, base.Position.Y + bob, base.Position.Z) * base.Rotation * face)
	end
end)

-- the distant windmill turns now and then; the Heartloom hums its tune; boards creak
task.spawn(function()
	local mill = hub.Background:FindFirstChild("PaperWindmill")
	local nextMotif = os.clock() + 50
	while true do
		task.wait(14 + math.random() * 10)
		if mill then
			mill:SetAttribute("Active", true)
			task.delay(6, function()
				mill:SetAttribute("Active", false)
			end)
		end
		if anyoneInHub() then
			Util.playAt(Vector3.new(330 + math.random() * 110, 30, -30), "WoodCreak", 0.15, 0.7 + math.random() * 0.3)
			if os.clock() > nextMotif then
				nextMotif = os.clock() + 70 + math.random() * 30
				motif(0.18)
			end
		end
	end
end)
