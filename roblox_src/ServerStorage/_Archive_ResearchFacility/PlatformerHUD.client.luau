-- PlatformerHUD: score, plane indicator, hints, toasts, results screen, costume menu, touch controls.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Platformer")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local level = workspace:WaitForChild("ResearchFacility")

local FONT = Enum.Font.GothamBold
local FONT_HEAVY = Enum.Font.GothamBlack
local CYAN = Color3.fromRGB(60, 225, 255)
local PANEL = Color3.fromRGB(16, 20, 30)

local gui = Instance.new("ScreenGui")
gui.Name = "PlatformerHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or CYAN
	s.Thickness = t or 1.5
	s.Transparency = 0.4
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end

local function label(parent, text, size, pos, ts, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos or UDim2.new()
	l.Text = text
	l.TextSize = ts or 18
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = font or FONT
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent, text, size, pos, color)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or Color3.fromRGB(30, 120, 160)
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = FONT_HEAVY
	b.TextSize = 18
	b.AutoButtonColor = true
	corner(b, 8)
	b.Parent = parent
	return b
end

---------------------------------------------------------------- stats panel
local stats = Instance.new("Frame")
stats.Size = UDim2.fromOffset(250, 118)
stats.Position = UDim2.fromOffset(16, 56)
stats.BackgroundColor3 = PANEL
stats.BackgroundTransparency = 0.25
corner(stats, 12)
stroke(stats)
stats.Parent = gui

label(stats, "THE RESEARCH FACILITY", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 8), 13, CYAN, FONT_HEAVY)
local scoreL = label(stats, "SCORE  0", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 28), 24, Color3.new(1, 1, 1), FONT_HEAVY)
local secretsL = label(stats, "SECRETS  0 / 0", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 56), 16, Color3.fromRGB(255, 120, 230))
local timeL = label(stats, "0:00", UDim2.new(0, 80, 0, 18), UDim2.new(1, -92, 0, 56), 16, Color3.fromRGB(200, 200, 210), FONT, Enum.TextXAlignment.Right)

local lanePills = {}
for i, name in ipairs(Config.LANE_NAMES) do
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromOffset(72, 24)
	pill.Position = UDim2.fromOffset(12 + (i - 1) * 78, 82)
	pill.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
	pill.Text = name:upper()
	pill.TextSize = 12
	pill.Font = FONT_HEAVY
	pill.TextColor3 = Color3.fromRGB(150, 160, 180)
	corner(pill, 12)
	pill.Parent = stats
	lanePills[i] = pill
end

local function refreshLane()
	local lane = player:GetAttribute("Lane") or 1
	for i, pill in ipairs(lanePills) do
		local on = i == lane
		pill.BackgroundColor3 = on and CYAN or Color3.fromRGB(40, 46, 60)
		pill.TextColor3 = on and PANEL or Color3.fromRGB(150, 160, 180)
	end
end
player:GetAttributeChangedSignal("Lane"):Connect(refreshLane)
refreshLane()

local totalSecrets = level:GetAttribute("Secrets") or 0
local function refreshScore()
	scoreL.Text = "SCORE  " .. tostring(player:GetAttribute("Score") or 0)
	secretsL.Text = ("SECRETS  %d / %d"):format(player:GetAttribute("SecretsFound") or 0, totalSecrets)
end
player:GetAttributeChangedSignal("Score"):Connect(refreshScore)
player:GetAttributeChangedSignal("SecretsFound"):Connect(refreshScore)
refreshScore()

local runStart = os.clock()
local finished = false
RunService.Heartbeat:Connect(function()
	if not finished then
		local t = os.clock() - runStart
		timeL.Text = ("%d:%02d"):format(t // 60, t % 60)
	end
end)

---------------------------------------------------------------- controls help
local help = Instance.new("Frame")
help.Size = UDim2.fromOffset(280, 176)
help.Position = UDim2.new(1, -296, 0, 56)
help.BackgroundColor3 = PANEL
help.BackgroundTransparency = 0.35
corner(help, 12)
stroke(help)
help.Parent = gui
local helpText = label(help, table.concat({
	"<b>A / D</b>   run",
	"<b>SPACE</b>   jump / climb / let go",
	"<b>W / S</b>   change plane (glowing zones)",
	"<b>E</b>   grab crate / swing object",
	"<b>F</b>   use switch or lever",
	"<b>R</b>   reset nearby crates",
	"<b>C</b>   costumes     <b>H</b>   hide help",
}, "\n"), UDim2.new(1, -20, 1, -16), UDim2.fromOffset(10, 8), 14, Color3.fromRGB(220, 225, 235))
helpText.RichText = true
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.LineHeight = 1.3

---------------------------------------------------------------- hint bar
local hint = label(gui, "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 1, -70), 20, Color3.fromRGB(255, 240, 180), FONT_HEAVY, Enum.TextXAlignment.Center)
hint.TextStrokeTransparency = 0.4
player:GetAttributeChangedSignal("Hint"):Connect(function()
	hint.Text = player:GetAttribute("Hint") or ""
end)

---------------------------------------------------------------- toasts
local toast = label(gui, "", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0.22, 0), 32, Color3.new(1, 1, 1), FONT_HEAVY, Enum.TextXAlignment.Center)
toast.TextStrokeTransparency = 0.2
toast.TextTransparency = 1
toast.TextStrokeTransparency = 1
local toastId = 0
local function showToast(text, color)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(1.6, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end
Remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)
player:GetAttributeChangedSignal("LocalNotify"):Connect(function()
	local v = player:GetAttribute("LocalNotify") or ""
	local text = v:match("^(.*)#") or v
	showToast(text, text == "SECRET FOUND!" and Color3.fromRGB(255, 120, 230) or Color3.fromRGB(255, 220, 140))
end)

---------------------------------------------------------------- costume menu
local profile = { unlocked = { "LabCoat" }, costume = "LabCoat", best = 0 }
local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(380, 360)
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.BackgroundColor3 = PANEL
menu.BackgroundTransparency = 0.05
menu.Visible = false
corner(menu, 14)
stroke(menu, CYAN, 2)
menu.Parent = gui
label(menu, "COSTUMES", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(16, 12), 24, CYAN, FONT_HEAVY)
local bestL = label(menu, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(16, 42), 14, Color3.fromRGB(180, 190, 200))
local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Size = UDim2.new(1, -32, 1, -120)
list.Position = UDim2.fromOffset(16, 68)
list.Parent = menu
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = list
local closeB = button(menu, "CLOSE", UDim2.fromOffset(120, 36), UDim2.new(0.5, -60, 1, -48), Color3.fromRGB(70, 76, 90))
closeB.MouseButton1Click:Connect(function()
	menu.Visible = false
end)

local function reqText(c)
	if c.req.secrets then
		return "Find every secret"
	elseif c.req.completed then
		return "Finish the level"
	elseif c.req.score and c.req.score > 0 then
		return ("Best score %d+"):format(c.req.score)
	end
	return "Starter"
end

local function rebuildMenu()
	for _, ch in ipairs(list:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	local unlocked = {}
	for _, id in ipairs(profile.unlocked or {}) do
		unlocked[id] = true
	end
	bestL.Text = ("Best score: %d     Secrets found ever: %d / %d"):format(profile.best or 0, profile.secretsEver or 0, profile.totalSecrets or totalSecrets)
	for _, c in ipairs(Config.COSTUMES) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
		row.Text = ""
		row.AutoButtonColor = unlocked[c.id] == true
		corner(row, 8)
		if profile.costume == c.id then
			stroke(row, CYAN, 2)
		end
		local sw = Instance.new("Frame")
		sw.Size = UDim2.fromOffset(26, 26)
		sw.Position = UDim2.fromOffset(8, 7)
		sw.BackgroundColor3 = c.color
		corner(sw, 13)
		sw.Parent = row
		label(row, c.name, UDim2.new(0.6, 0, 1, 0), UDim2.fromOffset(44, 0), 16, unlocked[c.id] and Color3.new(1, 1, 1) or Color3.fromRGB(120, 125, 135), FONT_HEAVY)
		label(row, unlocked[c.id] and (profile.costume == c.id and "EQUIPPED" or "EQUIP") or ("LOCKED - " .. reqText(c)), UDim2.new(0.5, -12, 1, 0), UDim2.new(0.5, 0, 0, 0), 12, unlocked[c.id] and CYAN or Color3.fromRGB(150, 150, 160), FONT, Enum.TextXAlignment.Right)
		row.Parent = list
		row.MouseButton1Click:Connect(function()
			if unlocked[c.id] then
				Remotes.SetCostume:FireServer(c.id)
			end
		end)
	end
end

Remotes:WaitForChild("ProfileUpdate").OnClientEvent:Connect(function(p)
	profile = p
	totalSecrets = p.totalSecrets or totalSecrets
	refreshScore()
	rebuildMenu()
end)
rebuildMenu()

local costumeB = button(gui, "COSTUMES", UDim2.fromOffset(120, 32), UDim2.fromOffset(16, 182), Color3.fromRGB(40, 60, 90))
costumeB.TextSize = 14
costumeB.MouseButton1Click:Connect(function()
	menu.Visible = not menu.Visible
end)

---------------------------------------------------------------- results screen
local results = Instance.new("Frame")
results.Size = UDim2.fromOffset(420, 330)
results.AnchorPoint = Vector2.new(0.5, 0.5)
results.Position = UDim2.fromScale(0.5, 0.5)
results.BackgroundColor3 = PANEL
results.Visible = false
corner(results, 16)
stroke(results, Color3.fromRGB(80, 255, 140), 2)
results.Parent = gui
label(results, "FACILITY ESCAPED!", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 18), 30, Color3.fromRGB(80, 255, 140), FONT_HEAVY, Enum.TextXAlignment.Center)
local resultsBody = label(results, "", UDim2.new(1, -40, 0, 170), UDim2.fromOffset(20, 66), 18, Color3.new(1, 1, 1), FONT, Enum.TextXAlignment.Center)
resultsBody.TextYAlignment = Enum.TextYAlignment.Top
resultsBody.RichText = true
resultsBody.LineHeight = 1.25
local replayB = button(results, "PLAY AGAIN", UDim2.fromOffset(170, 44), UDim2.new(0.5, -180, 1, -64), Color3.fromRGB(40, 150, 90))
local costumesB2 = button(results, "COSTUMES", UDim2.fromOffset(170, 44), UDim2.new(0.5, 10, 1, -64), Color3.fromRGB(40, 90, 150))
replayB.MouseButton1Click:Connect(function()
	results.Visible = false
	finished = false
	runStart = os.clock()
	Remotes.Replay:FireServer()
end)
costumesB2.MouseButton1Click:Connect(function()
	menu.Visible = true
end)

local function fmt(t)
	if not t then
		return "-"
	end
	return ("%d:%05.2f"):format(t // 60, t % 60)
end

Remotes:WaitForChild("LevelComplete").OnClientEvent:Connect(function(r)
	finished = true
	local lines = {
		("Score  <b>%d</b>   (best %d)"):format(r.score, r.best),
		("Collected  %d / %d"):format(r.collected, r.totalCollectibles),
		("Secrets  <font color='#ff78e6'>%d / %d</font>"):format(r.secrets, r.totalSecrets),
		("Time  %s   (best %s)"):format(fmt(r.time), fmt(r.bestTime)),
	}
	if #r.unlocked > 0 then
		table.insert(lines, "")
		table.insert(lines, "<font color='#3ce1ff'><b>UNLOCKED:</b> " .. table.concat(r.unlocked, ", ") .. "</font>")
	end
	resultsBody.Text = table.concat(lines, "\n")
	results.Visible = true
end)

---------------------------------------------------------------- keys
UserInputService.InputBegan:Connect(function(io, processed)
	if processed then
		return
	end
	if io.KeyCode == Enum.KeyCode.C then
		menu.Visible = not menu.Visible
	elseif io.KeyCode == Enum.KeyCode.H then
		help.Visible = not help.Visible
	end
end)

---------------------------------------------------------------- touch controls
if UserInputService.TouchEnabled then
	help.Visible = false
	local client = player:WaitForChild("PlayerScripts"):WaitForChild("PlatformerClient")
	local touch = client:WaitForChild("TouchInput")
	local pad = Instance.new("Frame")
	pad.BackgroundTransparency = 1
	pad.Size = UDim2.new(1, 0, 0, 170)
	pad.Position = UDim2.new(0, 0, 1, -180)
	pad.Parent = gui
	local function tbtn(text, pos, size)
		local b = button(pad, text, size or UDim2.fromOffset(74, 74), pos, Color3.fromRGB(30, 40, 60))
		b.BackgroundTransparency = 0.3
		b.TextSize = 24
		corner(b, 37)
		return b
	end
	local left = tbtn("<", UDim2.fromOffset(24, 80))
	local right = tbtn(">", UDim2.fromOffset(110, 80))
	local up = tbtn("^", UDim2.fromOffset(67, 0), UDim2.fromOffset(74, 64))
	local jump = tbtn("JUMP", UDim2.new(1, -110, 0, 70), UDim2.fromOffset(90, 90))
	jump.TextSize = 18
	local grab = tbtn("GRAB", UDim2.new(1, -200, 0, 96), UDim2.fromOffset(74, 74))
	grab.TextSize = 16
	local down = tbtn("v", UDim2.new(1, -200, 0, 10), UDim2.fromOffset(74, 64))
	local held = { l = false, r = false }
	local function sendMove()
		touch:Fire("Move", (held.r and 1 or 0) - (held.l and 1 or 0))
	end
	left.MouseButton1Down:Connect(function() held.l = true sendMove() end)
	left.MouseButton1Up:Connect(function() held.l = false sendMove() end)
	left.MouseLeave:Connect(function() held.l = false sendMove() end)
	right.MouseButton1Down:Connect(function() held.r = true sendMove() end)
	right.MouseButton1Up:Connect(function() held.r = false sendMove() end)
	right.MouseLeave:Connect(function() held.r = false sendMove() end)
	jump.MouseButton1Down:Connect(function() touch:Fire("Jump") end)
	grab.MouseButton1Down:Connect(function() touch:Fire("Grab") end)
	up.MouseButton1Down:Connect(function() touch:Fire("Up") end)
	down.MouseButton1Down:Connect(function() touch:Fire("Down") end)
end
