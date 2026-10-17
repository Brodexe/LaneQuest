-- DemoConnection: the thread spindle in the exit doorway and the hidden passage it opens into the Loomworks.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Travel = require(script.Parent:WaitForChild("Travel"))
local Util = require(script.Parent:WaitForChild("Util"))
local Slapped = script.Parent:WaitForChild("Slapped")

local map = workspace:WaitForChild("PaperWorkshop")
local mech = map:WaitForChild("Mechanisms")
local spindle = mech:WaitForChild("Spindle"):WaitForChild("Spindle")
local core = spindle.PrimaryPart
local glow = mech.Spindle:WaitForChild("DoorGlow"):FindFirstChildOfClass("PointLight")
local front = mech:WaitForChild("CartonFront")
local flap = mech:WaitForChild("WallFlap")
local works = mech:WaitForChild("TunnelWorks")
local toHub = map:WaitForChild("Triggers"):WaitForChild("ToHub")

local winds, opened = 0, false
local burstUntil = 0

local function open()
	opened = true
	map:SetAttribute("PassageOpen", true)
	spindle:SetAttribute("Speed", 22)
	Util.playAt(core.Position, "WindUp", 0.8, 1.1)
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - core.Position).Magnitude < 45 then
			Travel.cue(p, Vector3.new(145, 16, 0), 50, 3.4)
		end
	end
	-- the thread pulls taut toward the side of the box
	local a, b = Vector3.new(131.7, 15.5, -2.4), Vector3.new(136.1, 16.2, -2.4)
	local taut = Instance.new("Part")
	taut.Name = "TautThread"
	taut.Anchored, taut.CanCollide, taut.CanQuery, taut.CanTouch = true, false, false, false
	taut.Material = Enum.Material.Fabric
	taut.Color = Color3.fromRGB(222, 156, 64)
	taut.Size = Vector3.new(0.07, 0.07, 0.05)
	taut.CFrame = CFrame.lookAt(a, b)
	taut.Parent = mech
	Util.tweenValue(0, 1, TweenInfo.new(0.35), function(k)
		local e = a:Lerp(b, k)
		taut.Size = Vector3.new(0.07, 0.07, math.max(0.05, (e - a).Magnitude))
		taut.CFrame = CFrame.lookAt((a + e) / 2, b)
	end)
	task.wait(0.6)
	-- the carton's front unfolds toward you
	Util.playAt(Vector3.new(147, 16, 4), "PaperRustle", 0.7)
	Util.playAt(Vector3.new(147, 14, 4), "Cardboard", 0.6, 0.85)
	Util.swingModel(front, CFrame.new(147.65, 12, 4.55), "X", 0, 168, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	task.wait(0.5)
	-- gears catch, the counterweight drops
	for _, g in ipairs(works:GetChildren()) do
		if g.Name:match("^Gear") then
			g:SetAttribute("Active", true)
		end
	end
	Util.playAt(Vector3.new(143, 17, -4), "GearClick", 0.7)
	Util.playAt(Vector3.new(150, 18, -2), "WoodCreak", 0.6)
	local bag, cord = works.Counterweight, works.WeightCord
	local top = 19.9
	Util.tweenValue(17, 12.85, TweenInfo.new(0.8, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), function(y)
		bag.Position = Vector3.new(bag.Position.X, y, bag.Position.Z)
		local len = top - (y + 0.85)
		cord.Size = Vector3.new(0.07, 0.07, math.max(0.1, len))
		cord.CFrame = CFrame.lookAt(Vector3.new(150.6, top - len / 2, -2.4), Vector3.new(150.6, top - len, -2.4))
	end)
	task.wait(0.3)
	-- the taped flap in the side of the box folds down into a floor
	Util.playAt(Vector3.new(136.4, 16, 0), "Cardboard", 0.8, 0.8)
	Util.swingModel(flap, CFrame.new(136.4, 12.05, 0.2), "Z", 0, -88, TweenInfo.new(0.8, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out))
	task.wait(0.6)
	-- the bulbs flicker on, one after another
	local bulbs = {}
	for _, b2 in ipairs(works:GetChildren()) do
		if b2.Name == "TunnelBulb" then
			table.insert(bulbs, b2)
		end
	end
	table.sort(bulbs, function(x, y)
		return x:GetAttribute("Order") < y:GetAttribute("Order")
	end)
	for _, bulb in ipairs(bulbs) do
		local light = bulb:FindFirstChildOfClass("PointLight")
		task.spawn(function()
			for _, on in ipairs({ true, false, true, false, true }) do
				light.Enabled = on
				bulb.Color = on and Color3.fromRGB(255, 232, 190) or Color3.fromRGB(150, 140, 120)
				task.wait(0.05 + math.random() * 0.07)
			end
		end)
		Util.playAt(bulb.Position, "GlassTink", 0.25, 1.4 + math.random() * 0.3)
		task.wait(0.18)
	end
	task.wait(1.5)
	spindle:SetAttribute("Speed", 0.6)
	glow.Brightness = 1.4
end

Slapped.Event:Connect(function(part, player)
	if part ~= core or opened then
		return
	end
	winds += 1
	burstUntil = os.clock() + 0.45
	spindle:SetAttribute("Speed", 9)
	Util.playAt(core.Position, "Ratchet", 0.7, 1.1 + winds * 0.15)
	glow.Brightness = 0.2 + winds * 0.4
	if winds >= 3 then
		task.spawn(open)
	end
end)

-- presence: it turns faster and chimes faintly when someone is close; walking through the felt curtain travels on
local lastTink = 0
while true do
	task.wait(0.25)
	local now = os.clock()
	if not opened and now > burstUntil then
		local _, d = Util.nearestPlayer(core.Position, 9)
		local near = d < 9
		spindle:SetAttribute("Speed", near and 2.2 or 0.35)
		if near and now - lastTink > 3.2 then
			lastTink = now
			Util.playAt(core.Position, "GlassTink", 0.18, 1.6 + math.random() * 0.4)
		end
	end
	if opened then
		for _, p in ipairs(Util.playersIn(toHub)) do
			if not Travel.isTravelling(p) then
				task.spawn(Travel.go, p, "Hub", "Arrival")
			end
		end
	end
end
