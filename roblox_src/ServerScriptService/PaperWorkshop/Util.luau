-- Util: small server helpers shared by the area scripts (sounds, speech bubbles, model tweens, volume checks).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("PaperWorkshop"):WaitForChild("Config"))

local Util = {}

function Util.playAt(position, key, volume, speed, lifetime)
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
	s.PlaybackSpeed = speed or (0.94 + math.random() * 0.12)
	s.RollOffMinDistance = 45
	s.RollOffMaxDistance = 220
	s.Parent = a
	s:Play()
	Debris:AddItem(a, lifetime or 6)
	return s
end

function Util.isInside(part, pos)
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

-- players whose root part is inside a trigger volume
function Util.playersIn(part)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp and Util.isInside(part, hrp.Position) then
			table.insert(list, p)
		end
	end
	return list
end

function Util.nearestPlayer(pos, maxDist)
	local best, bestD = nil, maxDist or math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best, bestD
end

-- tween any number from a to b, calling onStep(value) on every change
function Util.tweenValue(from, to, info, onStep)
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(onStep)
	local t = TweenService:Create(v, info, { Value = to })
	t.Completed:Connect(function()
		v:Destroy()
	end)
	t:Play()
	return t
end

-- slide a model between two pivots
function Util.tweenModel(model, fromCF, toCF, info)
	return Util.tweenValue(0, 1, info, function(a)
		model:PivotTo(fromCF:Lerp(toCF, a))
	end)
end

-- swing a model around a hinge CFrame (angle in degrees about the hinge's local axis)
function Util.swingModel(model, hingeCF, axis, fromDeg, toDeg, info)
	local rel = hingeCF:ToObjectSpace(model:GetPivot())
	return Util.tweenValue(fromDeg, toDeg, info, function(deg)
		local r = math.rad(deg)
		local rot = axis == "X" and CFrame.Angles(r, 0, 0) or (axis == "Y" and CFrame.Angles(0, r, 0) or CFrame.Angles(0, 0, r))
		model:PivotTo(hingeCF * rot * rel)
	end)
end

-- a paper speech bubble above a character; lines play one after another
local speaking = {}
function Util.say(anchor, lines, opts)
	opts = opts or {}
	if type(lines) == "string" then
		lines = { lines }
	end
	speaking[anchor] = (speaking[anchor] or 0) + 1
	local token = speaking[anchor]
	task.spawn(function()
		local old = anchor:FindFirstChild("Speech")
		if old then
			old:Destroy()
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "Speech"
		gui.Size = UDim2.fromOffset(280, 92)
		gui.StudsOffsetWorldSpace = opts.offset or Vector3.new(0, 3.6, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.fromScale(0.5, 1)
		card.Size = UDim2.fromScale(0, 0)
		card.BackgroundColor3 = Color3.fromRGB(240, 230, 206)
		card.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = card
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(62, 50, 42)
		s.Thickness = 2
		s.Parent = card
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(10, 6)
		t.Size = UDim2.new(1, -20, 1, -12)
		t.FontFace = Font.fromEnum(Enum.Font.PatrickHand)
		t.TextColor3 = Color3.fromRGB(62, 50, 42)
		t.TextSize = 24
		t.TextWrapped = true
		t.Parent = card
		card.Parent = gui
		gui.Parent = anchor
		for _, line in ipairs(lines) do
			if speaking[anchor] ~= token then
				return
			end
			t.Text = line
			card.Size = UDim2.fromScale(0.2, 0.2)
			TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
			task.wait(math.clamp(1.4 + #line * 0.055, 2, 5.5))
		end
		if speaking[anchor] == token and gui.Parent then
			TweenService:Create(card, TweenInfo.new(0.2), { Size = UDim2.fromScale(0, 0) }):Play()
			task.wait(0.22)
			gui:Destroy()
		end
	end)
end

return Util
