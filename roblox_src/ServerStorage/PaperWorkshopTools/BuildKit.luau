-- BuildKit: edit-time helpers for building Paper Workshop levels in the house style (card, paper, wood, felt, thread).
-- Not used at runtime. Require a clone from the command bar / MCP so edits are picked up:
--   local K = require(game.ServerStorage.PaperWorkshopTools.BuildKit:Clone())
-- Conventions: X runs along the level, Y up, Z depth. Layers at Z = 0 (front), -4 (middle) and -8 (back);
-- players step between them with W/S wherever there's room and floor (lane zones are no longer used).
-- 1 stud is about 1.5 cm of the real object, so the player is a small figure about 7.5 cm tall.
-- Groups of similar things (books, pins, buttons) always vary size, colour, wear and angle (slop M51/M16).
local CollectionService = game:GetService("CollectionService")

local K = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
K.rgb = rgb

K.C = {
	kraft = rgb(196, 152, 104), kraftLight = rgb(218, 182, 136), kraftDark = rgb(146, 108, 70), flute = rgb(170, 126, 82), rib = rgb(206, 166, 118),
	wood = rgb(214, 178, 126), woodMid = rgb(164, 120, 78), woodDark = rgb(110, 76, 50), woodDeep = rgb(70, 56, 46), floor = rgb(150, 108, 70),
	paper = rgb(242, 232, 206), paperOld = rgb(238, 229, 210), paperDim = rgb(219, 197, 166), plaster = rgb(206, 190, 166),
	ink = rgb(62, 50, 42), teal = rgb(84, 136, 134), tealDark = rgb(58, 100, 100), mustard = rgb(212, 166, 68),
	red = rgb(186, 64, 50), redDark = rgb(132, 44, 38), brass = rgb(176, 140, 72), tin = rgb(148, 148, 142),
	leather = rgb(110, 76, 50), sage = rgb(120, 138, 98), plum = rgb(108, 74, 92), slate = rgb(78, 88, 100),
	thread = rgb(222, 156, 64), felt = rgb(150, 66, 56), cream = rgb(240, 230, 206), glass = rgb(190, 210, 210),
}

---------------------------------------------------------------- randomness (seeded, so rebuilds are repeatable)
K.rng = Random.new(1)
function K.seed(n)
	K.rng = Random.new(n)
end
function K.r(a, b)
	return a + (b - a) * K.rng:NextNumber()
end
function K.ri(a, b)
	return K.rng:NextInteger(a, b)
end
function K.pick(list)
	return list[K.rng:NextInteger(1, #list)]
end
function K.chance(p)
	return K.rng:NextNumber() < p
end
-- nudge a colour's hue/saturation/value a little (heterogeneous groups)
function K.jitter(c, amt)
	amt = amt or 0.06
	local h, s, v = c:ToHSV()
	h = (h + K.r(-amt, amt) * 0.4) % 1
	s = math.clamp(s + K.r(-amt, amt), 0, 1)
	v = math.clamp(v + K.r(-amt, amt), 0, 1)
	return Color3.fromHSV(h, s, v)
end
function K.mix(a, b, t)
	return a:Lerp(b, t)
end

---------------------------------------------------------------- containers
K.parent = workspace
function K.into(p)
	local old = K.parent
	K.parent = p
	return old
end
function K.folder(parent, name, class)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new(class or "Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
function K.model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or K.parent
	return m
end

local function toCF(cf)
	if typeof(cf) == "Vector3" then
		return CFrame.new(cf)
	end
	return cf
end
K.toCF = toCF

---------------------------------------------------------------- primitives
-- opts: deco (no collision/query/touch), noShadow, t (transparency), parent, shape, refl, collide (override), query
function K.part(class, name, size, cf, color, mat, opts)
	opts = opts or {}
	local p = Instance.new(class)
	p.Name = name
	p.Anchored = opts.anchored ~= false
	p.Size = size
	p.CFrame = toCF(cf)
	p.Color = color or K.C.kraft
	p.Material = mat or Enum.Material.Cardboard
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.deco then
		p.CanCollide = false
		p.CanQuery = opts.query == true
		p.CanTouch = false
	end
	if opts.collide ~= nil then
		p.CanCollide = opts.collide
	end
	if opts.noShadow or (opts.deco and size.Magnitude < 1.2) then
		p.CastShadow = false
	end
	if opts.t then
		p.Transparency = opts.t
	end
	if opts.refl then
		p.Reflectance = opts.refl
	end
	p.Parent = opts.parent or K.parent
	return p
end
function K.box(name, size, cf, color, mat, opts)
	return K.part("Part", name, size, cf, color, mat, opts)
end
function K.wedge(name, size, cf, color, mat, opts)
	return K.part("WedgePart", name, size, cf, color, mat, opts)
end
-- cylinder whose axis is the CFrame's X axis
function K.cyl(name, length, diameter, cf, color, mat, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	return K.part("Part", name, Vector3.new(length, diameter, diameter), cf, color, mat, opts)
end
-- upright cylinder standing on its centre point
function K.post(name, height, diameter, pos, color, mat, opts)
	return K.cyl(name, height, diameter, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat, opts)
end
-- a cylinder lying along Z (depth): good for wheels/discs seen face-on from the camera
function K.disc(name, thick, diameter, pos, color, mat, opts)
	return K.cyl(name, thick, diameter, CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0), color, mat, opts)
end
function K.ball(name, d, pos, color, mat, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Ball
	return K.part("Part", name, Vector3.new(d, d, d), toCF(pos), color, mat, opts)
end
-- a thin straight line between two points (threads, wires, cords)
function K.line(name, a, b, thick, color, mat, opts)
	opts = opts or {}
	if opts.deco == nil then
		opts.deco = true
	end
	local len = (b - a).Magnitude
	return K.box(name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color or K.C.ink, mat or Enum.Material.Fabric, opts)
end
-- a sagging thread: n straight pieces along a shallow curve
function K.sag(name, a, b, droop, thick, color, n, opts)
	n = n or 6
	local pts = {}
	for i = 0, n do
		local t = i / n
		table.insert(pts, a:Lerp(b, t) - Vector3.new(0, droop * 4 * t * (1 - t), 0))
	end
	local parts = {}
	for i = 1, n do
		table.insert(parts, K.line(name, pts[i], pts[i + 1], thick, color, Enum.Material.Fabric, opts))
	end
	return parts, pts
end

-- handwriting on a face of a part
function K.text(part, face, text, opts)
	opts = opts or {}
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opts.pps or 40
	g.LightInfluence = opts.light or 1
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = Font.fromEnum(opts.font or Enum.Font.PatrickHand)
	l.Text = text
	l.TextScaled = opts.scaled ~= false
	l.TextSize = opts.size or 30
	l.TextWrapped = true
	l.RichText = true
	l.TextColor3 = opts.color or K.C.ink
	l.Rotation = opts.rot or 0
	l.Parent = g
	return g, l
end

function K.light(part, kind, brightness, range, color, opts)
	local l = Instance.new(kind or "PointLight")
	l.Brightness = brightness or 1
	l.Range = range or 14
	l.Color = color or rgb(255, 214, 160)
	l.Shadows = opts and opts.shadows or false
	if opts and opts.face and l:IsA("SpotLight") then
		l.Face = opts.face
		l.Angle = opts.angle or 70
	end
	l.Parent = part
	return l
end

function K.tag(inst, ...)
	for _, t in ipairs({ ... }) do
		CollectionService:AddTag(inst, t)
	end
	return inst
end
function K.attrs(inst, t)
	for k, v in pairs(t) do
		inst:SetAttribute(k, v)
	end
	return inst
end

---------------------------------------------------------------- gameplay volumes (invisible)
local function volume(name, pos, size, parent)
	local p = K.box(name, size, pos, K.C.kraft, Enum.Material.Cardboard, { deco = true, t = 1, parent = parent })
	p.CastShadow = false
	return p
end
K.volume = volume
function K.laneZone(name, pos, size, fromLane, toLane, dir, parent)
	local z = volume(name, pos, size, parent)
	K.attrs(z, { FromLane = fromLane, ToLane = toLane, Dir = dir })
	return K.tag(z, "LaneZone")
end
-- a two-way lane crossing at x: walking dir (+1/-1) moves front->back; the reverse brings you out again
function K.laneCrossing(name, x, y, dir, parent, width)
	width = width or 3.6
	K.laneZone(name .. "_In", Vector3.new(x, y + 3, 0), Vector3.new(width, 6, 6), 1, 2, dir, parent)
	K.laneZone(name .. "_Out", Vector3.new(x, y + 3, -8), Vector3.new(width, 6, 6), 2, 1, -dir, parent)
end
function K.kill(name, pos, size, parent, sound)
	local z = volume(name, pos, size, parent)
	if sound then
		z:SetAttribute("Sound", sound)
	end
	return K.tag(z, "KillVolume")
end
function K.spawnPart(spawns, name, pos)
	local old = spawns:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local s = K.box(name, Vector3.new(2, 0.2, 2), pos, K.C.kraft, Enum.Material.Cardboard, { deco = true, t = 1, parent = spawns })
	return s
end
-- a checkpoint: volume + spawn + (optional) marker model that raises its flag when reached
function K.checkpoint(areaName, spawns, triggers, name, pos, order, marker)
	K.spawnPart(spawns, name, pos)
	local cp = volume("CP_" .. name, pos + Vector3.new(0, 4, -4), Vector3.new(4, 10, 14), triggers)
	K.attrs(cp, { Spawn = name, Order = order, Area = areaName })
	K.tag(cp, "Checkpoint")
	if marker then
		local ref = Instance.new("ObjectValue")
		ref.Name = "Marker"
		ref.Value = marker
		ref.Parent = cp
		K.tag(marker, "CheckpointMarker")
	end
	return cp
end

-- movers (see ReplicatedStorage.PaperWorkshop.Motion)
function K.mover(inst, kind, attrs)
	local base = inst:IsA("Model") and inst:GetPivot() or inst.CFrame
	inst:SetAttribute("BaseCF", base)
	inst:SetAttribute("Kind", kind)
	K.attrs(inst, attrs or {})
	return K.tag(inst, "Mover")
end

-- a loose physics prop the player can grab, slap and throw
function K.prop(p, soundKey)
	p.Anchored = false
	p:SetAttribute("Home", p.CFrame)
	p:SetAttribute("PropMaterial", soundKey or "Cardboard")
	return K.tag(p, "Prop", "Grabbable")
end

function K.keepsake(inst, id, title, note)
	K.attrs(inst, { Id = id, Title = title, Note = note })
	for _, p in ipairs(inst:IsA("BasePart") and { inst } or inst:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
		end
	end
	return K.tag(inst, "Keepsake")
end

---------------------------------------------------------------- art prefabs
-- corrugated card slab (the house platform): kraft skins, fluted core, ribs on the front edge
function K.slab(name, cf, sx, sz, t, opts)
	opts = opts or {}
	t = t or 1.4
	cf = toCF(cf)
	local m = K.model(name, opts.parent)
	local top = opts.top or K.jitter(K.C.kraftLight, 0.025)
	K.box("Surface", Vector3.new(sx, 0.24, sz), cf * CFrame.new(0, t / 2 - 0.12, 0), top, Enum.Material.Cardboard, { parent = m })
	K.box("Liner", Vector3.new(sx, 0.24, sz), cf * CFrame.new(0, -t / 2 + 0.12, 0), opts.liner or K.C.kraft, Enum.Material.Cardboard, { parent = m })
	K.box("Flutes", Vector3.new(sx - 0.12, t - 0.48, sz - 0.2), cf * CFrame.new(0, 0, -0.04), K.C.flute, Enum.Material.Cardboard, { parent = m })
	if opts.ribs ~= false and t >= 0.8 then
		local step = 0.62
		local n = math.floor((sx - 0.4) / step)
		for i = 0, n do
			local x = -sx / 2 + 0.3 + i * step
			K.box("Rib", Vector3.new(0.2, t - 0.48, 0.1), cf * CFrame.new(x, 0, sz / 2 - 0.12), K.C.rib, Enum.Material.Cardboard, { parent = m, deco = true })
		end
	end
	return m
end

-- a book. cf = centre; size = (width X, thickness Y, depth Z) when lying flat
function K.book(name, cf, size, opts)
	opts = opts or {}
	cf = toCF(cf)
	local m = K.model(name, opts.parent)
	local cover = opts.cover or K.jitter(K.pick({ K.C.redDark, K.C.tealDark, K.C.leather, K.C.mustard, K.C.sage, K.C.plum, K.C.slate, K.C.woodDark }), 0.05)
	local pages = opts.pages or K.jitter(K.C.paperOld, 0.03)
	local ct = math.min(0.4, size.Y * 0.12)
	local mat = opts.mat or (K.chance(0.6) and Enum.Material.Leather or Enum.Material.Fabric)
	local collide = opts.deco and { parent = m, deco = true } or { parent = m }
	K.box("CoverTop", Vector3.new(size.X, ct, size.Z), cf * CFrame.new(0, size.Y / 2 - ct / 2, 0), cover, mat, collide)
	K.box("CoverBottom", Vector3.new(size.X, ct, size.Z), cf * CFrame.new(0, -size.Y / 2 + ct / 2, 0), cover, mat, collide)
	K.box("Spine", Vector3.new(size.X, size.Y, ct), cf * CFrame.new(0, 0, -size.Z / 2 + ct / 2), cover, mat, collide)
	K.box("Pages", Vector3.new(size.X - 0.3, size.Y - ct * 2, size.Z - ct - 0.15), cf * CFrame.new(0, 0, 0.075 - ct / 2 + ct / 2), pages, Enum.Material.Plaster, collide)
	if opts.band then
		K.box("Band", Vector3.new(0.5, size.Y + 0.02, ct + 0.02), cf * CFrame.new(size.X * K.r(-0.3, 0.3), 0, -size.Z / 2 + ct / 2), K.C.brass, Enum.Material.Fabric, { parent = m, deco = true })
	end
	return m
end

-- a book standing on a shelf: cf at the bottom-centre of the book, width = thickness along X
function K.standingBook(name, bottomCF, thick, height, depth, opts)
	opts = opts or {}
	local m = K.model(name, opts.parent)
	local cover = opts.cover or K.jitter(K.pick({ K.C.redDark, K.C.tealDark, K.C.leather, K.C.mustard, K.C.sage, K.C.plum, K.C.slate, K.C.woodDark, K.C.paperDim }), 0.07)
	local cf = bottomCF * CFrame.new(0, height / 2, 0)
	local deco = opts.deco and true or false
	K.box("Body", Vector3.new(thick, height, depth), cf, cover, opts.mat or K.pick({ Enum.Material.Leather, Enum.Material.Fabric, Enum.Material.Cardboard }), { parent = m, deco = deco })
	K.box("Pages", Vector3.new(thick - 0.14, height - 0.3, 0.06), cf * CFrame.new(0, 0, -depth / 2 - 0.02), K.jitter(K.C.paperOld, 0.04), Enum.Material.Plaster, { parent = m, deco = true })
	if K.chance(opts.bandChance or 0.45) then
		local y = K.r(-0.35, 0.35) * height
		K.box("Band", Vector3.new(thick + 0.02, K.r(0.12, 0.3), 0.06), cf * CFrame.new(0, y, depth / 2 + 0.01), K.pick({ K.C.brass, K.C.cream, K.C.ink }), Enum.Material.Fabric, { parent = m, deco = true })
	end
	return m
end

-- a row of standing books along +X from bottomLeftCF, filling `length`, heterogeneous: sizes, lean, gaps, a few lying flat
function K.bookRow(name, startCF, length, maxH, depth, opts)
	opts = opts or {}
	local m = K.model(name, opts.parent)
	local x = 0
	while x < length - 0.6 do
		local roll = K.rng:NextNumber()
		if roll < 0.07 and length - x > 3 then
			x += K.r(0.8, 2.4) -- a gap
		elseif roll < 0.15 and length - x > maxH * 0.8 then
			-- a small stack lying flat
			local w = math.min(maxH * K.r(0.6, 0.9), length - x - 0.2)
			local y = 0
			for _ = 1, K.ri(1, 3) do
				local th = K.r(0.4, 0.9)
				K.book("FlatBook", startCF * CFrame.new(x + w / 2, y + th / 2, 0) * CFrame.Angles(0, math.rad(K.r(-4, 4)), 0), Vector3.new(w * K.r(0.85, 1), th, depth * K.r(0.8, 1)), { parent = m, deco = opts.deco })
				y += th
			end
			x += w + K.r(0.05, 0.3)
		else
			local th = K.r(0.35, 1.3)
			local h = maxH * K.r(0.6, 1)
			local lean = 0
			if roll > 0.9 then
				lean = K.r(8, 22)
			end
			local bottom = startCF * CFrame.new(x + th / 2, 0, K.r(-0.25, 0.25)) * CFrame.Angles(0, 0, math.rad(-lean))
			if lean > 0 then
				bottom = bottom * CFrame.new(math.sin(math.rad(lean)) * h * 0.1, 0, 0)
			end
			K.standingBook("Book", bottom, th, h, depth * K.r(0.75, 1), { parent = m, deco = opts.deco })
			x += th + (lean > 0 and h * math.sin(math.rad(lean)) or K.r(0, 0.08))
		end
	end
	return m
end

-- a wooden pencil lying along the CFrame's X axis (hexagon approximated by three crossed boxes)
function K.pencil(name, cf, length, d, color, opts)
	opts = opts or {}
	cf = toCF(cf)
	local m = K.model(name, opts.parent)
	local body = length * 0.86
	local deco = opts.deco
	for i = 0, 2 do
		K.box("Body", Vector3.new(body, d * 0.866, d * 0.5), cf * CFrame.new(-length * 0.07, 0, 0) * CFrame.Angles(math.rad(60 * i), 0, 0), color or K.C.mustard, Enum.Material.SmoothPlastic, { parent = m, deco = deco or i > 0 })
	end
	K.cyl("Wood", length * 0.1, d * 0.8, cf * CFrame.new(length * 0.41, 0, 0), K.C.wood, Enum.Material.Wood, { parent = m, deco = true })
	K.cyl("Lead", length * 0.04, d * 0.3, cf * CFrame.new(length * 0.48, 0, 0), K.C.ink, Enum.Material.SmoothPlastic, { parent = m, deco = true })
	if opts.eraser ~= false then
		K.cyl("Ferrule", length * 0.04, d * 0.95, cf * CFrame.new(-length * 0.5 + length * 0.02, 0, 0), K.C.tin, Enum.Material.Metal, { parent = m, deco = true })
	end
	return m
end

-- a wooden thread spool standing upright (bottom at pos)
function K.spool(name, bottom, height, d, threadColor, opts)
	opts = opts or {}
	local m = K.model(name, opts.parent)
	local fl = math.max(0.3, height * 0.1)
	K.post("FlangeBottom", fl, d, bottom + Vector3.new(0, fl / 2, 0), K.C.wood, Enum.Material.Wood, { parent = m })
	K.post("FlangeTop", fl, d, bottom + Vector3.new(0, height - fl / 2, 0), K.C.wood, Enum.Material.Wood, { parent = m })
	K.post("Thread", height - fl * 2, d * 0.78, bottom + Vector3.new(0, height / 2, 0), threadColor or K.C.teal, Enum.Material.Fabric, { parent = m })
	return m
end

-- a sewing button lying flat, face up (holes as dark dots)
function K.button(name, pos, d, color, opts)
	opts = opts or {}
	local m = K.model(name, opts.parent)
	local t = opts.thick or d * 0.14
	K.post("Disc", t, d, pos, color or K.C.cream, Enum.Material.SmoothPlastic, { parent = m, deco = opts.deco })
	K.post("Rim", t * 0.4, d * 0.7, pos + Vector3.new(0, t * 0.6, 0), K.jitter(color or K.C.cream, 0.04), Enum.Material.SmoothPlastic, { parent = m, deco = true })
	local holes = opts.holes or (K.chance(0.5) and 4 or 2)
	for i = 1, holes do
		local a = (i / holes) * math.pi * 2 + math.pi / 4
		K.post("Hole", 0.04, d * 0.1, pos + Vector3.new(math.cos(a) * d * 0.12, t * 0.82, math.sin(a) * d * 0.12), K.C.ink, Enum.Material.SmoothPlastic, { parent = m, deco = true })
	end
	return m
end

-- a push pin / sewing pin stuck in at an angle: head ball + shaft
function K.pin(name, tip, dir, length, headD, headColor, opts)
	opts = opts or {}
	local m = K.model(name, opts.parent)
	local head = tip + dir.Unit * length
	K.line("Shaft", tip, head, math.max(0.08, headD * 0.18), K.C.tin, Enum.Material.Metal, { parent = m, deco = opts.deco ~= false })
	K.ball("Head", headD, head, headColor or K.C.red, Enum.Material.SmoothPlastic, { parent = m, deco = opts.deco })
	return m
end

-- an eraser block (rounded edges suggested by a darker band)
function K.eraser(name, cf, size, color, opts)
	opts = opts or {}
	local m = K.model(name, opts.parent)
	K.box("Rubber", size, cf, color or rgb(226, 150, 140), Enum.Material.Rubber, { parent = m })
	if opts.sleeve ~= false then
		K.box("Sleeve", Vector3.new(size.X * 0.55, size.Y + 0.04, size.Z + 0.04), toCF(cf) * CFrame.new(size.X * 0.18, 0, 0), opts.sleeveColor or K.C.slate, Enum.Material.Cardboard, { parent = m, deco = true })
	end
	return m
end

-- a wooden ruler lying flat along X with numbers printed on top
function K.ruler(name, cf, length, width, opts)
	opts = opts or {}
	local m = K.model(name, opts.parent)
	local p = K.box("Ruler", Vector3.new(length, opts.thick or 0.5, width), cf, opts.color or K.C.wood, Enum.Material.Wood, { parent = m })
	local nums = {}
	for i = 1, math.floor(length / 6.6) do
		table.insert(nums, tostring(i))
	end
	K.text(p, Enum.NormalId.Top, table.concat(nums, "        "), { pps = 18, color = K.C.ink, font = Enum.Font.Oswald })
	return m
end

return K
