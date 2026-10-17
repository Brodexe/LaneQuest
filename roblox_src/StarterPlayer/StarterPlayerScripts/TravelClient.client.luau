-- TravelClient: the paper-curtain transition between areas, plus each area's lighting mood, music and ambience.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("PaperWorkshop")
local Config = require(Shared:WaitForChild("Config"))
local Areas = require(Shared:WaitForChild("Areas"))
local Remotes = Shared:WaitForChild("Remotes")

---------------------------------------------------------------- curtain: two kraft panels meet in the middle, stitched, sealed with the knot-eye mark
local KRAFT = Color3.fromRGB(196, 152, 104)
local INK = Color3.fromRGB(62, 50, 42)
local gui = Instance.new("ScreenGui")
gui.Name = "TravelCurtain"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local function panel(side)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(0.52, 1)
	f.BackgroundColor3 = side == "L" and KRAFT or Color3.fromRGB(184, 140, 94)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(side == "L" and 1 or 0, 0)
	f.Position = UDim2.fromScale(side == "L" and 0 or 1, 0)
	-- a row of stitches along the inner edge
	for i = 0, 18 do
		local st = Instance.new("Frame")
		st.Size = UDim2.new(0, 3, 0.028, 0)
		st.Position = UDim2.new(side == "L" and 1 or 0, side == "L" and -14 or 11, i / 19 + 0.008, 0)
		st.BackgroundColor3 = Color3.fromRGB(240, 230, 206)
		st.BorderSizePixel = 0
		st.Parent = f
	end
	f.Parent = gui
	return f
end
local left, right = panel("L"), panel("R")

local seal = Instance.new("Frame")
seal.AnchorPoint = Vector2.new(0.5, 0.5)
seal.Position = UDim2.fromScale(0.5, 0.5)
seal.Size = UDim2.fromOffset(84, 84)
seal.BackgroundColor3 = Color3.fromRGB(186, 64, 50)
seal.BackgroundTransparency = 1
seal.Parent = gui
local sealCorner = Instance.new("UICorner")
sealCorner.CornerRadius = UDim.new(0.5, 0)
sealCorner.Parent = seal
-- the knot-eye: a ring with a thread through it
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromScale(0.55, 0.55)
ring.BackgroundTransparency = 1
ring.Parent = seal
local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0.5, 0)
rc.Parent = ring
local rs = Instance.new("UIStroke")
rs.Color = Color3.fromRGB(240, 230, 206)
rs.Thickness = 4
rs.Transparency = 1
rs.Parent = ring
local thread = Instance.new("Frame")
thread.AnchorPoint = Vector2.new(0.5, 0.5)
thread.Position = UDim2.fromScale(0.5, 0.5)
thread.Size = UDim2.new(0.8, 0, 0, 4)
thread.Rotation = -35
thread.BackgroundColor3 = Color3.fromRGB(240, 230, 206)
thread.BackgroundTransparency = 1
thread.BorderSizePixel = 0
thread.Parent = seal

local closed = false
local closedAt = 0
local function setCurtain(close)
	closed = close
	closedAt = os.clock()
	local info = TweenInfo.new(close and 0.5 or 0.55, Enum.EasingStyle.Quad, close and Enum.EasingDirection.In or Enum.EasingDirection.Out)
	TweenService:Create(left, info, { Position = UDim2.fromScale(close and 0.52 or 0, 0) }):Play()
	TweenService:Create(right, info, { Position = UDim2.fromScale(close and 0.48 or 1, 0) }):Play()
	local fade = TweenInfo.new(close and 0.35 or 0.2)
	TweenService:Create(seal, fade, { BackgroundTransparency = close and 0 or 1 }):Play()
	TweenService:Create(rs, fade, { Transparency = close and 0 or 1 }):Play()
	TweenService:Create(thread, fade, { BackgroundTransparency = close and 0 or 1 }):Play()
end

---------------------------------------------------------------- lighting moods
local warmth = Lighting:FindFirstChild("WorkshopWarmth")
local function applyLighting(areaName)
	local preset = Areas.Lighting[Areas.get(areaName).lighting]
	if not preset then
		return
	end
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	if warmth then
		warmth.TintColor = preset.Tint
		warmth.Saturation = preset.Saturation
		warmth.Contrast = preset.Contrast
	end
end

---------------------------------------------------------------- music and ambience, cross-faded per area
local loops = {}
local function loop(key, volume)
	if not loops[key] then
		local s = Instance.new("Sound")
		s.Name = "Area_" .. key
		s.SoundId = Config.Sounds[key]
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		s:Play()
		loops[key] = { sound = s, volume = volume }
	end
	return loops[key]
end

local function applyAudio(areaName)
	local area = Areas.get(areaName)
	local wanted = {}
	if area.music then
		wanted[area.music] = Config.MUSIC_VOLUME
	end
	if area.ambience then
		wanted[area.ambience] = 0.16
	end
	for key, vol in pairs(wanted) do
		loop(key, vol)
	end
	for key, l in pairs(loops) do
		local target = wanted[key] or 0
		TweenService:Create(l.sound, TweenInfo.new(1.5), { Volume = target }):Play()
	end
end

local currentArea
local function enterArea(areaName)
	if areaName == currentArea then
		return
	end
	currentArea = areaName
	applyLighting(areaName)
	applyAudio(areaName)
end

Remotes:WaitForChild("Transition").OnClientEvent:Connect(function(phase, areaName)
	if phase == "close" then
		setCurtain(true)
	elseif phase == "open" then
		enterArea(areaName or player:GetAttribute("Area"))
		setCurtain(false)
	end
end)
player:GetAttributeChangedSignal("Area"):Connect(function()
	if not closed then
		enterArea(player:GetAttribute("Area"))
	end
end)
enterArea(player:GetAttribute("Area") or "Demo")

-- safety: never leave the curtain shut if the "open" message is lost
task.spawn(function()
	while true do
		task.wait(0.5)
		if closed and os.clock() - closedAt > 4 then
			enterArea(player:GetAttribute("Area"))
			setCurtain(false)
		end
	end
end)
