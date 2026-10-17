-- LevelKit: the reusable toolkit every level is built from.
-- Every gameplay object is a tagged part with attributes, so the runtime systems
-- (ServerScriptService.Platformer) drive any level built with this kit.
--
-- Coordinates: X = along the level, Y = up, lanes are fixed Z planes (Config.LANE_Z).
-- `lanes` arguments accept a number (one lane) or a table of lanes {1,2,3}.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Platformer"):WaitForChild("Config"))

local Kit = {}
Kit.__index = Kit

local HALF = Config.LANE_DEPTH / 2

local PALETTE = {
	concrete = Color3.fromRGB(120, 124, 132),
	steel = Color3.fromRGB(82, 90, 102),
	dark = Color3.fromRGB(38, 42, 52),
	tile = Color3.fromRGB(214, 222, 228),
	hazardYellow = Color3.fromRGB(245, 196, 40),
	cyan = Color3.fromRGB(60, 225, 255),
	green = Color3.fromRGB(80, 255, 140),
	red = Color3.fromRGB(255, 50, 60),
	wood = Color3.fromRGB(160, 112, 64),
}
Kit.PALETTE = PALETTE

local function laneRange(lanes)
	if type(lanes) == "number" then
		lanes = { lanes }
	end
	local minL, maxL = math.huge, -math.huge
	for _, l in ipairs(lanes) do
		minL = math.min(minL, l)
		maxL = math.max(maxL, l)
	end
	-- lane 1 has the largest Z
	local zFront = Config.laneZ(minL) + HALF
	local zBack = Config.laneZ(maxL) - HALF
	return zFront, zBack, minL, maxL
end
Kit.laneRange = laneRange

function Kit.new(levelName: string, parent: Instance?)
	local self = setmetatable({}, Kit)
	local old = (parent or workspace):FindFirstChild(levelName)
	if old then
		old:Destroy()
	end
	self.root = Instance.new("Model")
	self.root.Name = levelName
	self.root.Parent = parent or workspace
	self.current = self.root
	self.count = 0
	self.collectCount = 0
	self:_laneAnchors()
	return self
end

function Kit:section(name: string)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = self.root
	self.current = f
	return f
end

local function tag(inst, tags)
	if tags then
		for _, t in ipairs(tags) do
			CollectionService:AddTag(inst, t)
		end
	end
end

local function attrs(inst, a)
	if a then
		for k, v in pairs(a) do
			inst:SetAttribute(k, v)
		end
	end
end

-- Generic part. o = {size, cframe | pos, color, material, transparency, collide, anchored, name, tags, attrs, shape, parent, reflectance, query, shadow}
function Kit:part(o)
	local p = Instance.new("Part")
	if o.shape then
		p.Shape = o.shape
	end
	p.Size = o.size
	p.CFrame = o.cframe or CFrame.new(o.pos)
	p.Anchored = o.anchored ~= false
	p.CanCollide = o.collide ~= false
	p.CanQuery = o.query ~= false
	p.CanTouch = o.touch ~= false
	p.CastShadow = o.shadow ~= false
	p.Color = o.color or PALETTE.concrete
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = o.name or "Part"
	tag(p, o.tags)
	attrs(p, o.attrs)
	p.Parent = o.parent or self.current
	self.count += 1
	return p
end

-- Non-colliding scenery.
function Kit:decor(o)
	o.collide = false
	o.query = false
	o.touch = false
	return self:part(o)
end

-- Box spanning X range, Y range and lanes.
function Kit:block(lanes, x1, x2, y1, y2, o)
	o = o or {}
	local zF, zB, minL = laneRange(lanes)
	if o.zFront then zF = o.zFront end
	if o.zBack then zB = o.zBack end
	o.size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(zF - zB))
	o.pos = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (zF + zB) / 2)
	o.name = o.name or "Block"
	local p = self:part(o)
	if o.fade then
		self:fade(p, minL)
	end
	return p
end

-- Walkable platform whose top surface is at yTop.
function Kit:platform(lanes, x1, x2, yTop, o)
	o = o or {}
	local t = o.thick or 2
	o.name = o.name or "Platform"
	o.material = o.material or Enum.Material.Metal
	o.color = o.color or PALETTE.steel
	local p = self:block(lanes, x1, x2, yTop - t, yTop, o)
	if o.trim ~= false then
		-- hazard-stripe trim on the front edge for readability
		local zF = select(1, laneRange(lanes))
		self:decor({
			size = Vector3.new(math.abs(x2 - x1), 0.35, 0.3),
			pos = Vector3.new((x1 + x2) / 2, yTop - 0.18, zF + 0.1),
			color = o.trimColor or PALETTE.hazardYellow,
			material = Enum.Material.Neon,
			name = "Trim",
			shadow = false,
		})
	end
	return p
end

function Kit:fade(part, lane)
	CollectionService:AddTag(part, "Fade")
	part:SetAttribute("Lane", lane)
	return part
end

function Kit:light(pos, color, range, brightness)
	local p = self:decor({ size = Vector3.new(0.4, 0.4, 0.4), pos = pos, transparency = 1, name = "Light" })
	local l = Instance.new("PointLight")
	l.Color = color or Color3.new(1, 1, 1)
	l.Range = range or 20
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = p
	return p
end

function Kit:sign(part, text, face, color)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBlack
	tl.TextColor3 = color or Color3.new(1, 1, 1)
	tl.Parent = sg
	sg.Parent = part
	return sg
end

-- Invisible per-lane reference parts used by PlaneConstraints to keep physics objects in their plane.
function Kit:_laneAnchors()
	local f = Instance.new("Folder")
	f.Name = "LaneAnchors"
	f.Parent = self.root
	self.anchors = {}
	for i, z in ipairs(Config.LANE_Z) do
		local p = Instance.new("Part")
		p.Name = "Lane" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(0, -200, z)
		local a = Instance.new("Attachment")
		a.Name = "Plane"
		a.Axis = Vector3.new(0, 0, 1)
		a.SecondaryAxis = Vector3.new(0, 1, 0)
		a.Parent = p
		p.Parent = f
		self.anchors[i] = a
	end
end

-- Lock a physics part to its lane plane and keep it upright.
function Kit:lockToLane(part, lane)
	local att = Instance.new("Attachment")
	att.Name = "LaneLock"
	att.Parent = part
	local pc = Instance.new("PlaneConstraint")
	pc.Attachment0 = self.anchors[lane]
	pc.Attachment1 = att
	pc.Parent = part
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = CFrame.identity
	ao.Parent = part
end

-- Movable crate. weight: 1 light (push freely), 2 medium, 3 heavy (must be grabbed and pulled slowly).
function Kit:crate(lane, x, yBottom, size, weight, o)
	o = o or {}
	size = size or 4
	weight = weight or 1
	local colors = { PALETTE.wood, Color3.fromRGB(70, 110, 160), Color3.fromRGB(150, 60, 50) }
	local pos = Vector3.new(x, yBottom + size / 2, Config.laneZ(lane))
	local p = self:part({
		size = Vector3.new(size, size, size),
		pos = pos,
		anchored = false,
		color = o.color or colors[weight] or PALETTE.wood,
		material = weight == 1 and Enum.Material.WoodPlanks or Enum.Material.DiamondPlate,
		name = o.name or (weight >= 3 and "HeavyCrate" or "Crate"),
		tags = { "Crate" },
		attrs = { Lane = lane, Weight = weight, Home = pos },
	})
	local density = ({ 0.6, 1.4, 3.5 })[weight] or 1
	p.CustomPhysicalProperties = PhysicalProperties.new(density, 0.55, 0, 1, 1)
	self:lockToLane(p, lane)
	-- weight label
	if weight >= 2 then
		self:sign(p, weight >= 3 and "HEAVY" or "MED", Enum.NormalId.Back, Color3.fromRGB(255, 230, 120))
	end
	return p
end

-- Grabbable suspended object. style: "container" | "hook" | "cable"
function Kit:swing(lane, pivotX, pivotY, length, o)
	o = o or {}
	local z = Config.laneZ(lane)
	local m = Instance.new("Model")
	m.Name = o.name or "Swing"
	m.Parent = self.current
	local pivot = self:part({
		size = Vector3.new(3, 1.5, 3),
		pos = Vector3.new(pivotX, pivotY, z),
		color = PALETTE.dark,
		material = Enum.Material.Metal,
		name = "Pivot",
		parent = m,
	})
	local cable = self:decor({
		size = Vector3.new(0.35, length, 0.35),
		pos = Vector3.new(pivotX, pivotY - length / 2, z),
		color = Color3.fromRGB(30, 30, 34),
		material = Enum.Material.Metal,
		name = "Cable",
		parent = m,
	})
	local style = o.style or "cable"
	local handle
	if style == "container" then
		handle = self:part({
			size = Vector3.new(7, 4, 4),
			pos = Vector3.new(pivotX, pivotY - length - 1.5, z),
			color = Color3.fromRGB(200, 80, 40),
			material = Enum.Material.CorrodedMetal,
			name = "Handle",
			collide = false,
			parent = m,
		})
	elseif style == "hook" then
		handle = self:part({
			size = Vector3.new(2, 2, 2),
			pos = Vector3.new(pivotX, pivotY - length, z),
			color = PALETTE.hazardYellow,
			material = Enum.Material.Metal,
			name = "Handle",
			collide = false,
			parent = m,
		})
	else
		handle = self:part({
			size = Vector3.new(1.4, 1.4, 1.4),
			shape = Enum.PartType.Ball,
			pos = Vector3.new(pivotX, pivotY - length, z),
			color = PALETTE.cyan,
			material = Enum.Material.Neon,
			name = "Handle",
			collide = false,
			parent = m,
		})
	end
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	grip.Position = style == "container" and Vector3.new(0, -2.2, 0) or Vector3.new(0, -0.6, 0)
	grip.Parent = handle
	local glow = Instance.new("PointLight")
	glow.Color = PALETTE.cyan
	glow.Range = 8
	glow.Brightness = 1
	glow.Parent = handle
	m.PrimaryPart = handle
	CollectionService:AddTag(m, "Swing")
	attrs(m, {
		Lane = lane,
		Length = length + (style == "container" and 3.7 or 0.6),
		Pivot = Vector3.new(pivotX, pivotY, z),
		IdleAmplitude = o.idle or 25,
		Theta = 0,
		Omega = 0,
	})
	return m
end

-- Designated lane-transition zone. lanes = lanes that can be moved between inside this zone.
function Kit:shiftZone(lanes, x1, x2, yBottom, height, o)
	o = o or {}
	height = height or 10
	local zF, zB, minL, maxL = laneRange(lanes)
	local list = {}
	for l = minL, maxL do
		table.insert(list, tostring(l))
	end
	local z = self:part({
		size = Vector3.new(math.abs(x2 - x1), height, math.abs(zF - zB) + 2),
		pos = Vector3.new((x1 + x2) / 2, yBottom + height / 2, (zF + zB) / 2),
		transparency = 1,
		collide = false,
		touch = false,
		name = "LaneShift",
		tags = { "LaneShift" },
		attrs = { Lanes = table.concat(list, ",") },
	})
	-- glowing floor marker on each connected lane plus connector strips between them
	for l = minL, maxL do
		self:decor({
			size = Vector3.new(math.abs(x2 - x1), 0.12, Config.LANE_DEPTH - 1),
			pos = Vector3.new((x1 + x2) / 2, yBottom + 0.07, Config.laneZ(l)),
			color = o.color or PALETTE.cyan,
			material = Enum.Material.Neon,
			transparency = 0.55,
			name = "ShiftMarker",
			shadow = false,
		})
		if l < maxL then
			self:decor({
				size = Vector3.new(math.abs(x2 - x1) * 0.5, 0.12, 12 - Config.LANE_DEPTH + 1),
				pos = Vector3.new((x1 + x2) / 2, yBottom + 0.07, (Config.laneZ(l) + Config.laneZ(l + 1)) / 2),
				color = o.color or PALETTE.cyan,
				material = Enum.Material.Neon,
				transparency = 0.4,
				name = "ShiftBridge",
				shadow = false,
			})
			-- walkable connector so you never fall between planes while shifting
			self:part({
				size = Vector3.new(math.abs(x2 - x1), 1, 12 - Config.LANE_DEPTH + 0.2),
				pos = Vector3.new((x1 + x2) / 2, yBottom - 0.5, (Config.laneZ(l) + Config.laneZ(l + 1)) / 2),
				color = PALETTE.dark,
				material = Enum.Material.DiamondPlate,
				name = "ShiftFloor",
			})
		end
	end
	return z
end

-- Pressure plate: active while total weight on it >= required (players weigh 1, crates use their Weight).
function Kit:plate(lane, x, yTop, required, channel, o)
	o = o or {}
	local w = o.width or 5
	local base = self:part({
		size = Vector3.new(w + 1, 0.4, Config.LANE_DEPTH - 2),
		pos = Vector3.new(x, yTop + 0.2, Config.laneZ(lane)),
		color = PALETTE.dark,
		material = Enum.Material.Metal,
		name = "PlateBase",
	})
	local pad = self:part({
		size = Vector3.new(w, 0.5, Config.LANE_DEPTH - 3),
		pos = Vector3.new(x, yTop + 0.55, Config.laneZ(lane)),
		color = PALETTE.red,
		material = Enum.Material.Neon,
		name = "PressurePlate",
		tags = { "PressurePlate" },
		attrs = { Channel = channel, Required = required or 1, Active = false, Lane = lane },
	})
	local label = self:decor({
		size = Vector3.new(w, 1.2, 0.1),
		pos = Vector3.new(x, yTop + 0.9, Config.laneZ(lane) + (Config.LANE_DEPTH - 2) / 2),
		transparency = 1,
		name = "PlateLabel",
	})
	self:sign(label, "WEIGHT " .. tostring(required or 1), Enum.NormalId.Back, Color3.fromRGB(255, 230, 120))
	return pad, base
end

-- Lever / switch. mode = "Toggle" (lever) | "Timed" (button, stays on o.time seconds) | "Sequence" (o.group, o.order)
function Kit:lever(lane, x, yBottom, channel, o)
	o = o or {}
	local z = Config.laneZ(lane) - 3
	local mode = o.mode or "Toggle"
	local base = self:part({
		size = Vector3.new(2, 3, 1),
		pos = Vector3.new(x, yBottom + 1.5, z),
		color = PALETTE.dark,
		material = Enum.Material.Metal,
		name = mode == "Toggle" and "Lever" or "Switch",
		tags = { "Switch" },
		attrs = {
			Channel = channel,
			Mode = mode,
			Time = o.time or 6,
			Group = o.group,
			Order = o.order,
			Active = false,
			Lane = lane,
		},
	})
	local knob = self:part({
		size = mode == "Toggle" and Vector3.new(0.4, 2, 0.4) or Vector3.new(1.2, 1.2, 0.5),
		pos = mode == "Toggle" and Vector3.new(x, yBottom + 3.6, z + 0.2) or Vector3.new(x, yBottom + 1.8, z + 0.6),
		color = PALETTE.red,
		material = Enum.Material.Neon,
		name = "Knob",
		collide = false,
		parent = base,
	})
	knob.Parent = base
	if o.label then
		self:sign(base, o.label, Enum.NormalId.Back)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = mode == "Toggle" and "Pull Lever" or "Press"
	prompt.ObjectText = o.label or "Switch"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	return base
end

-- Door that retracts (collapses toward one side) while its channel is active.
-- retract = "Up" | "Down" | "Left" | "Right"
function Kit:door(lanes, x1, x2, y1, y2, channel, retract, o)
	o = o or {}
	o.color = o.color or Color3.fromRGB(60, 70, 85)
	o.material = o.material or Enum.Material.DiamondPlate
	o.name = o.name or "Door"
	o.tags = { "Door" }
	o.attrs = { Channel = channel, Retract = retract or "Up", Logic = o.logic or "All" }
	local d = self:block(lanes, x1, x2, y1, y2, o)
	d:SetAttribute("ClosedCFrame", d.CFrame)
	d:SetAttribute("ClosedSize", d.Size)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Back
	light.Color = PALETTE.red
	light.Range = 6
	light.Brightness = 1
	light.Parent = d
	return d
end

-- Moving platform. offset = displacement from start to end.
-- o.mode = "Loop" (ping-pong forever) | "Channel" (sits at A, moves to B while channel active)
function Kit:mover(lanes, x1, x2, yTop, offset, o)
	o = o or {}
	local t = o.thick or 1.5
	local zF, zB = laneRange(lanes)
	local a = Vector3.new((x1 + x2) / 2, yTop - t / 2, (zF + zB) / 2)
	local p = self:part({
		size = Vector3.new(math.abs(x2 - x1), t, math.abs(zF - zB)),
		pos = a,
		anchored = false,
		color = o.color or Color3.fromRGB(70, 160, 220),
		material = o.material or Enum.Material.Metal,
		name = o.name or "MovingPlatform",
		tags = o.hazard and { "MovingPlatform", "Hazard" } or { "MovingPlatform" },
		attrs = {
			PointA = a,
			PointB = a + offset,
			Mode = o.mode or "Loop",
			Channel = o.channel,
			Speed = o.speed or 8,
			Wait = o.wait or 1.5,
			Logic = o.logic or "All",
			Phase = o.phase or 0,
		},
	})
	p.CustomPhysicalProperties = PhysicalProperties.new(2, 1, 0, 100, 1)
	if not o.hazard then
		self:decor({
			size = Vector3.new(p.Size.X, 0.25, 0.3),
			cframe = p.CFrame * CFrame.new(0, t / 2 - 0.12, p.Size.Z / 2 + 0.1),
			color = PALETTE.cyan,
			material = Enum.Material.Neon,
			name = "Edge",
			parent = p,
			anchored = false,
		})
		local edge = p:FindFirstChild("Edge")
		edge.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = edge
		w.Parent = edge
	end
	return p
end

-- Deadly hazard volume. o.interval -> blinks on/off (on for interval, off for o.off or interval). o.offset = phase.
function Kit:hazard(lanes, x1, x2, y1, y2, o)
	o = o or {}
	o.color = o.color or PALETTE.red
	o.material = o.material or Enum.Material.Neon
	o.transparency = o.transparency or 0.25
	o.collide = false
	o.shadow = false
	o.name = o.name or "Hazard"
	o.tags = { "Hazard" }
	o.attrs = { Interval = o.interval, OffTime = o.off, Offset = o.offset or 0, Active = true }
	return self:block(lanes, x1, x2, y1, y2, o)
end

function Kit:checkpoint(lane, x, yTop, order)
	local z = Config.laneZ(lane)
	local p = self:part({
		size = Vector3.new(4, 0.4, 4),
		pos = Vector3.new(x, yTop + 0.2, z),
		color = Color3.fromRGB(90, 100, 110),
		material = Enum.Material.Metal,
		name = "Checkpoint" .. order,
		tags = { "Checkpoint" },
		attrs = { Order = order, Lane = lane },
		collide = true,
	})
	local pole = self:decor({
		size = Vector3.new(0.4, 6, 0.4),
		pos = Vector3.new(x - 1.6, yTop + 3, z - 1.6),
		color = PALETTE.dark,
		material = Enum.Material.Metal,
		name = "Pole",
		parent = p,
	})
	local lamp = self:decor({
		size = Vector3.new(1, 1, 1),
		shape = Enum.PartType.Ball,
		pos = Vector3.new(x - 1.6, yTop + 6.3, z - 1.6),
		color = Color3.fromRGB(255, 120, 40),
		material = Enum.Material.Neon,
		name = "Lamp",
		parent = p,
	})
	-- touch volume
	self:part({
		size = Vector3.new(6, 8, Config.LANE_DEPTH),
		pos = Vector3.new(x, yTop + 4, z),
		transparency = 1,
		collide = false,
		query = false,
		name = "Trigger",
		parent = p,
	})
	return p
end

function Kit:_collectible(lane, x, y, value, secret)
	self.collectCount += 1
	local z = Config.laneZ(lane)
	local p = self:part({
		size = secret and Vector3.new(2.2, 2.2, 2.2) or Vector3.new(1.4, 1.4, 1.4),
		shape = secret and Enum.PartType.Block or Enum.PartType.Ball,
		cframe = CFrame.new(x, y, z) * (secret and CFrame.Angles(math.rad(45), 0, math.rad(45)) or CFrame.identity),
		color = secret and Color3.fromRGB(255, 70, 220) or Color3.fromRGB(120, 230, 255),
		material = secret and Enum.Material.Glass or Enum.Material.Neon,
		transparency = secret and 0.1 or 0.15,
		collide = false,
		name = secret and "SecretPrize" or "ScoreBubble",
		tags = { "Collectible" },
		attrs = { Value = value, Secret = secret, Id = (secret and "S" or "B") .. self.collectCount, Lane = lane },
		shadow = false,
	})
	if secret then
		local l = Instance.new("PointLight")
		l.Color = p.Color
		l.Range = 10
		l.Brightness = 2
		l.Parent = p
	end
	return p
end

function Kit:bubble(lane, x, y)
	return self:_collectible(lane, x, y, Config.BUBBLE_VALUE, false)
end

function Kit:bubbleRow(lane, x1, x2, y, n)
	for i = 0, n - 1 do
		local t = n == 1 and 0.5 or i / (n - 1)
		self:bubble(lane, x1 + (x2 - x1) * t, y)
	end
end

function Kit:bubbleArc(lane, cx, cy, radius, a1, a2, n)
	for i = 0, n - 1 do
		local a = math.rad(a1 + (a2 - a1) * (i / math.max(1, n - 1)))
		self:bubble(lane, cx + math.sin(a) * radius, cy - math.cos(a) * radius)
	end
end

function Kit:secret(lane, x, y)
	return self:_collectible(lane, x, y, Config.SECRET_VALUE, true)
end

function Kit:exit(lane, x, yTop)
	local z = Config.laneZ(lane)
	local pad = self:part({
		size = Vector3.new(6, 0.5, Config.LANE_DEPTH - 2),
		pos = Vector3.new(x, yTop + 0.25, z),
		color = PALETTE.green,
		material = Enum.Material.Neon,
		name = "Exit",
		tags = { "Exit" },
	})
	local beam = self:decor({
		size = Vector3.new(5, 30, 5),
		shape = Enum.PartType.Cylinder,
		cframe = CFrame.new(x, yTop + 15, z) * CFrame.Angles(0, 0, math.rad(90)),
		color = PALETTE.green,
		material = Enum.Material.ForceField,
		transparency = 0.2,
		name = "ExitBeam",
		parent = pad,
	})
	local trig = self:part({
		size = Vector3.new(6, 8, Config.LANE_DEPTH),
		pos = Vector3.new(x, yTop + 4, z),
		transparency = 1,
		collide = false,
		query = false,
		name = "Trigger",
		parent = pad,
	})
	return pad
end

function Kit:finish()
	local total, secrets = 0, 0
	for _, d in ipairs(self.root:GetDescendants()) do
		if CollectionService:HasTag(d, "Collectible") then
			total += 1
			if d:GetAttribute("Secret") then
				secrets += 1
			end
		end
	end
	self.root:SetAttribute("Collectibles", total)
	self.root:SetAttribute("Secrets", secrets)
	return self.count, total, secrets
end

return Kit
