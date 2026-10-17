-- Mechanisms: generic channel-driven machinery for any LevelKit level.
-- Sources (PressurePlate, Switch) set Active; listeners (Door, MovingPlatform[Mode=Channel]) react to their Channel.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Platformer")
local Remotes = Shared:WaitForChild("Remotes")
local SwingSync = Remotes:WaitForChild("SwingSync")
local level = workspace:WaitForChild("ResearchFacility")

local GREEN = Color3.fromRGB(80, 255, 140)
local RED = Color3.fromRGB(255, 50, 60)

local function tagged(tag)
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsDescendantOf(level) then
			table.insert(list, inst)
		end
	end
	return list
end

-- Channels -----------------------------------------------------------------
local sources = {} -- channel -> {parts}
local listeners = {} -- channel -> {callbacks}

local function addSource(part)
	local ch = part:GetAttribute("Channel")
	if ch then
		sources[ch] = sources[ch] or {}
		table.insert(sources[ch], part)
	end
end

local function channelActive(ch, logic)
	local list = sources[ch]
	if not list or #list == 0 then
		return false
	end
	if logic == "Any" then
		for _, s in ipairs(list) do
			if s:GetAttribute("Active") then
				return true
			end
		end
		return false
	end
	for _, s in ipairs(list) do
		if not s:GetAttribute("Active") then
			return false
		end
	end
	return true
end

local function listen(ch, fn)
	listeners[ch] = listeners[ch] or {}
	table.insert(listeners[ch], fn)
end

local function setActive(part, on)
	if part:GetAttribute("Active") == on then
		return
	end
	part:SetAttribute("Active", on)
	local ch = part:GetAttribute("Channel")
	if ch and listeners[ch] then
		for _, fn in ipairs(listeners[ch]) do
			task.spawn(fn)
		end
	end
end

-- Pressure plates ----------------------------------------------------------
local plates = tagged("PressurePlate")
local plateBase = {}
for _, p in ipairs(plates) do
	addSource(p)
	plateBase[p] = p.CFrame
end

local plateParams = OverlapParams.new()
plateParams.FilterType = Enum.RaycastFilterType.Exclude

task.spawn(function()
	while true do
		task.wait(0.1)
		for _, p in ipairs(plates) do
			local base = plateBase[p]
			plateParams.FilterDescendantsInstances = { p }
			local parts = workspace:GetPartBoundsInBox(base * CFrame.new(0, 2.2, 0), Vector3.new(p.Size.X, 4, p.Size.Z + 1), plateParams)
			local weight, seen = 0, {}
			for _, part in ipairs(parts) do
				if CollectionService:HasTag(part, "Crate") then
					if not seen[part] then
						seen[part] = true
						weight += part:GetAttribute("Weight") or 1
					end
				else
					local model = part:FindFirstAncestorOfClass("Model")
					local hum = model and model:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 and not seen[model] then
						seen[model] = true
						weight += 1
					end
				end
			end
			local on = weight >= (p:GetAttribute("Required") or 1)
			p:SetAttribute("Weight", weight)
			if on ~= p:GetAttribute("Active") then
				p.Color = on and GREEN or RED
				p.CFrame = on and base * CFrame.new(0, -0.3, 0) or base
				setActive(p, on)
			end
		end
	end
end)

-- Switches (levers, timed buttons, sequence switches) ---------------------
local sequenceGroups = {} -- group -> {switches, progress, solved}

local function knobOf(sw)
	return sw:FindFirstChild("Knob")
end

local function setKnob(sw, color)
	local k = knobOf(sw)
	if k then
		k.Color = color
	end
end

local function makeTimerLabel(sw)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Timer"
	bb.Size = UDim2.fromOffset(80, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Enabled = false
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.fromRGB(255, 200, 60)
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	bb.Parent = sw
	return bb, t
end

for _, sw in ipairs(tagged("Switch")) do
	addSource(sw)
	local mode = sw:GetAttribute("Mode")
	local prompt = sw:FindFirstChildOfClass("ProximityPrompt")
	if mode == "Sequence" then
		local g = sw:GetAttribute("Group")
		sequenceGroups[g] = sequenceGroups[g] or { switches = {}, progress = 0, solved = false }
		table.insert(sequenceGroups[g].switches, sw)
	end
	local endsAt = 0
	local bb, label
	if mode == "Timed" then
		bb, label = makeTimerLabel(sw)
	end
	prompt.Triggered:Connect(function()
		if mode == "Toggle" then
			local on = not sw:GetAttribute("Active")
			setKnob(sw, on and GREEN or RED)
			local k = knobOf(sw)
			if k then
				k.CFrame = sw.CFrame * CFrame.new(0, 2.1, 0.2) * CFrame.Angles(0, 0, on and -0.6 or 0)
			end
			prompt.ActionText = on and "Reset Lever" or "Pull Lever"
			setActive(sw, on)
		elseif mode == "Timed" then
			local dur = sw:GetAttribute("Time") or 6
			endsAt = os.clock() + dur
			if sw:GetAttribute("Active") then
				return
			end
			setKnob(sw, GREEN)
			setActive(sw, true)
			bb.Enabled = true
			task.spawn(function()
				while os.clock() < endsAt do
					label.Text = string.format("%.1f", endsAt - os.clock())
					task.wait(0.1)
				end
				bb.Enabled = false
				setKnob(sw, RED)
				setActive(sw, false)
			end)
		elseif mode == "Sequence" then
			local g = sequenceGroups[sw:GetAttribute("Group")]
			if g.solved then
				return
			end
			if sw:GetAttribute("Order") == g.progress + 1 then
				g.progress += 1
				setKnob(sw, GREEN)
				if g.progress >= #g.switches then
					g.solved = true
					for _, s in ipairs(g.switches) do
						local pr = s:FindFirstChildOfClass("ProximityPrompt")
						if pr then
							pr.Enabled = false
						end
						setActive(s, true)
					end
				end
			else
				g.progress = 0
				for _, s in ipairs(g.switches) do
					setKnob(s, Color3.fromRGB(255, 255, 255))
				end
				task.delay(0.4, function()
					if not g.solved then
						for _, s in ipairs(g.switches) do
							setKnob(s, RED)
						end
					end
				end)
			end
		end
	end)
end

-- Doors --------------------------------------------------------------------
for _, d in ipairs(tagged("Door")) do
	local closedCF = d:GetAttribute("ClosedCFrame") or d.CFrame
	local closedSize = d:GetAttribute("ClosedSize") or d.Size
	local dir = d:GetAttribute("Retract") or "Up"
	local openSize, openCF
	if dir == "Up" or dir == "Down" then
		openSize = Vector3.new(closedSize.X, 0.4, closedSize.Z)
		local s = (closedSize.Y - 0.4) / 2 * (dir == "Up" and 1 or -1)
		openCF = closedCF * CFrame.new(0, s, 0)
	else
		openSize = Vector3.new(0.3, closedSize.Y, closedSize.Z)
		local s = (closedSize.X - 0.3) / 2 * (dir == "Right" and 1 or -1)
		openCF = closedCF * CFrame.new(s, 0, 0)
	end
	local light = d:FindFirstChildOfClass("SurfaceLight")
	local ch = d:GetAttribute("Channel")
	local logic = d:GetAttribute("Logic") or "All"
	local isOpen = false
	listen(ch, function()
		local on = channelActive(ch, logic)
		if on == isOpen then
			return
		end
		isOpen = on
		if light then
			light.Color = on and GREEN or RED
		end
		TweenService:Create(d, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = on and openSize or closedSize,
			CFrame = on and openCF or closedCF,
		}):Play()
	end)
end

-- Moving platforms ---------------------------------------------------------
local movers = {}
for _, m in ipairs(tagged("MovingPlatform")) do
	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = m
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.RigidityEnabled = true
	ap.Position = m:GetAttribute("PointA")
	ap.Parent = m
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = CFrame.identity
	ao.Parent = m
	pcall(function()
		m:SetNetworkOwner(nil)
	end)
	local info = {
		part = m,
		ap = ap,
		a = m:GetAttribute("PointA"),
		b = m:GetAttribute("PointB"),
		speed = m:GetAttribute("Speed") or 8,
		wait = m:GetAttribute("Wait") or 1,
		mode = m:GetAttribute("Mode") or "Loop",
		phase = m:GetAttribute("Phase") or 0,
		channel = m:GetAttribute("Channel"),
		logic = m:GetAttribute("Logic") or "All",
		pos = m:GetAttribute("PointA"),
		target = m:GetAttribute("PointA"),
	}
	if info.mode == "Channel" and info.channel then
		listen(info.channel, function()
			info.target = channelActive(info.channel, info.logic) and info.b or info.a
		end)
	end
	table.insert(movers, info)
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	for _, info in ipairs(movers) do
		if info.mode == "Loop" then
			local dist = (info.b - info.a).Magnitude
			local travel = dist / info.speed
			local cycle = 2 * (travel + info.wait)
			local t = (clock + info.phase * cycle) % cycle
			local alpha
			if t < info.wait then
				alpha = 0
			elseif t < info.wait + travel then
				alpha = (t - info.wait) / travel
			elseif t < 2 * info.wait + travel then
				alpha = 1
			else
				alpha = 1 - (t - 2 * info.wait - travel) / travel
			end
			alpha = (1 - math.cos(alpha * math.pi)) / 2
			info.pos = info.a:Lerp(info.b, alpha)
		else
			local delta = info.target - info.pos
			local step = info.speed * dt
			if delta.Magnitude <= step then
				info.pos = info.target
			else
				info.pos += delta.Unit * step
			end
		end
		info.ap.Position = info.pos
	end
end)

-- Timed hazards (lasers) ---------------------------------------------------
for _, h in ipairs(tagged("Hazard")) do
	local interval = h:GetAttribute("Interval")
	if interval then
		local off = h:GetAttribute("OffTime") or interval
		local offset = h:GetAttribute("Offset") or 0
		local onT = h.Transparency
		task.spawn(function()
			task.wait(offset)
			while true do
				h:SetAttribute("Active", true)
				h.Transparency = onT
				h.CanTouch = true
				task.wait(interval)
				h:SetAttribute("Active", false)
				h.Transparency = 0.92
				h.CanTouch = false
				task.wait(off)
			end
		end)
	end
end

-- Swings (server-side pendulum; the grabbing client streams its state) ----
local swings = {}
for _, m in ipairs(tagged("Swing")) do
	local pivotPart = m:FindFirstChild("Pivot")
	local pivotCF = CFrame.new(m:GetAttribute("Pivot"))
	local parts = {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= pivotPart then
			parts[p] = pivotCF:ToObjectSpace(p.CFrame)
		end
	end
	table.insert(swings, {
		model = m,
		pivot = pivotCF,
		parts = parts,
		length = m:GetAttribute("Length"),
		amp = math.rad(m:GetAttribute("IdleAmplitude") or 20),
		theta = math.rad(m:GetAttribute("IdleAmplitude") or 20) * 0.9,
		omega = 0,
		grabbedBy = nil,
		lastSync = 0,
	})
end

local swingByModel = {}
for _, s in ipairs(swings) do
	swingByModel[s.model] = s
end

SwingSync.OnServerEvent:Connect(function(player, model, theta, omega, holding)
	local s = swingByModel[model]
	if not s or type(theta) ~= "number" or type(omega) ~= "number" then
		return
	end
	if theta ~= theta or omega ~= omega then
		return
	end
	if s.grabbedBy and s.grabbedBy ~= player and os.clock() - s.lastSync < 0.6 then
		return
	end
	s.theta = math.clamp(theta, -1.45, 1.45)
	s.omega = math.clamp(omega, -8, 8)
	s.grabbedBy = holding and player or nil
	s.lastSync = os.clock()
	model:SetAttribute("HeldBy", holding and player.UserId or 0)
end)

RunService.Heartbeat:Connect(function(dt)
	local g = workspace.Gravity
	for _, s in ipairs(swings) do
		local held = s.grabbedBy and os.clock() - s.lastSync < 0.6
		if not held then
			s.grabbedBy = nil
			local L = s.length
			local alpha = -(g / L) * math.sin(s.theta) - 0.08 * s.omega
			-- gently pump toward the idle amplitude so it is always catchable
			local energy = 0.5 * (s.omega * L) ^ 2 + g * L * (1 - math.cos(s.theta))
			local target = g * L * (1 - math.cos(s.amp))
			if energy < target then
				local dir = s.omega >= 0 and 1 or -1
				if math.abs(s.omega) < 0.02 then
					dir = s.theta <= 0 and 1 or -1
				end
				alpha += dir * 0.9
			elseif energy > target * 1.4 then
				alpha -= 0.6 * s.omega
			end
			s.omega += alpha * dt
			s.theta = math.clamp(s.theta + s.omega * dt, -1.45, 1.45)
		else
			s.theta += s.omega * dt -- extrapolate between client updates
		end
		local rot = s.pivot * CFrame.Angles(0, 0, s.theta)
		for p, offset in pairs(s.parts) do
			p.CFrame = rot * offset
		end
		s.model:SetAttribute("Theta", s.theta)
		s.model:SetAttribute("Omega", s.omega)
	end
end)
