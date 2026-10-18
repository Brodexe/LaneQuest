-- Critters: the small made things that wander the levels. Tag "Critter" on a Model whose PrimaryPart is "Root";
-- the "Species" attribute picks the behaviour below. Contact and stomps are reported by the touching client
-- (LevelClient) through LevelRuntime; this script owns movement and reactions.
--   WindupMouse  walks its ledge and turns at edges and walls. A stomp or a slap flips it on its back: it stays
--                down a few seconds and can be carried, thrown or used as a weight, then rights itself where it lies.
--   JackInTheBox pops when you come close: in front of it you get knocked back, standing on the lid you get launched.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("PaperWorkshop"):WaitForChild("Config"))
local Util = require(script.Parent:WaitForChild("Util"))
local Slapped = script.Parent:WaitForChild("Slapped")
local CritterStomped = script.Parent:WaitForChild("CritterStomped")
local Launch = script.Parent:WaitForChild("Launch")
local HurtPlayer = script.Parent:WaitForChild("HurtPlayer")

local species = {}
local state = {} -- per critter model

local function laneZ(z)
	return Config.LANES[Config.nearestLane(z)]
end

local function hrpOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local function refreshRayFilter()
	local list = {}
	for _, c in ipairs(CollectionService:GetTagged("Critter")) do
		table.insert(list, c)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

-- drive a critter's root with bounded align constraints (smooth on clients, no fighting the physics)
local function rig(model)
	local root = model.PrimaryPart
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.Massless = true
			if not p:FindFirstChild("CritterWeld") then
				local w = Instance.new("WeldConstraint")
				w.Name = "CritterWeld"
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.RigidityEnabled = true
	ap.Position = root.Position
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = root.CFrame.Rotation
	ao.Parent = root
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return ap, ao
end

---------------------------------------------------------------- Wind-up mouse
species.WindupMouse = {}
function species.WindupMouse.init(model, s)
	local root = model.PrimaryPart
	s.ap, s.ao = rig(model)
	s.home = root.CFrame
	s.dir = model:GetAttribute("Dir") or 1
	s.speed = model:GetAttribute("Speed") or 5
	s.halfH = root.Size.Y / 2
	s.pos = root.Position
	s.key = model:FindFirstChild("Key")
	s.keyAngle = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
	root.CanQuery = true
	CollectionService:AddTag(root, "Slappable")
	model:SetAttribute("Stompable", true)
end

local function mouseFlip(model, s, byDir)
	if s.stunned then
		s.downUntil = os.clock() + 5
		return
	end
	s.stunned = true
	s.downUntil = os.clock() + 5
	model:SetAttribute("Stunned", true)
	local root = model.PrimaryPart
	s.ap.Enabled = false
	s.ao.Enabled = false
	root.CanCollide = true
	root.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.6, 0.2)
	CollectionService:AddTag(root, "Grabbable")
	root:SetAttribute("PropMaterial", "Fabric")
	local m = root.AssemblyMass
	root:ApplyImpulse(Vector3.new((byDir or 0) * 6, 16, 0) * m)
	root:ApplyAngularImpulse(Vector3.new(0, 0, (byDir ~= 0 and -byDir or 1) * 9) * m)
	Util.playAt(root.Position, "WindUp", 0.5, 1.9)
	Util.playAt(root.Position, "Fabric", 0.6, 1.2)
end

local function mouseRecover(model, s)
	local root = model.PrimaryPart
	if root:GetAttribute("HeldBy") then
		s.downUntil = os.clock() + 1.5
		return
	end
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -4, 0), rayParams)
	if not hit or root.AssemblyLinearVelocity.Magnitude > 2 then
		s.downUntil = os.clock() + 0.6
		return
	end
	s.stunned = false
	model:SetAttribute("Stunned", nil)
	CollectionService:RemoveTag(root, "Grabbable")
	root.CanCollide = false
	s.pos = Vector3.new(root.Position.X, hit.Position.Y + s.halfH, laneZ(root.Position.Z))
	s.ap.Position = s.pos
	s.ap.Enabled = true
	s.ao.Enabled = true
	Util.playAt(root.Position, "Ratchet", 0.4, 1.6)
end

function species.WindupMouse.step(model, s, dt, now)
	local root = model.PrimaryPart
	if s.stunned then
		if not root:GetAttribute("HeldBy") then
			-- keep it in its lane and turning only in the play plane, like the other props
			local pos = root.Position
			local lz = laneZ(pos.Z)
			if math.abs(pos.Z - lz) > 0.05 then
				local rv = root.CFrame.RightVector
				root.CFrame = CFrame.new(pos.X, pos.Y, lz) * CFrame.Angles(0, 0, math.atan2(rv.Y, rv.X))
			end
			local v = root.AssemblyLinearVelocity
			if math.abs(v.Z) > 0.01 then
				root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
			end
			if pos.Y < (model:GetAttribute("FloorY") or -1000) then
				-- fell out of the world: back home, upright
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = s.home
			end
		end
		s.keyAngle += dt * 14
		if now > s.downUntil then
			mouseRecover(model, s)
		end
		return
	end
	-- walking: feel ahead for floor and walls, turn at either
	local ahead = s.pos + Vector3.new(s.dir * (root.Size.X / 2 + 0.4), 0, 0)
	local floor = workspace:Raycast(ahead + Vector3.new(0, 0.5, 0), Vector3.new(0, -(s.halfH + 1.6), 0), rayParams)
	local wall = workspace:Raycast(s.pos, Vector3.new(s.dir * (root.Size.X / 2 + 0.3), 0, 0), rayParams)
	local minX, maxX = model:GetAttribute("MinX"), model:GetAttribute("MaxX")
	if not floor or wall or (minX and ahead.X < minX) or (maxX and ahead.X > maxX) then
		s.dir = -s.dir
		s.pauseUntil = now + 0.35
	elseif not s.pauseUntil or now > s.pauseUntil then
		s.pos = Vector3.new(s.pos.X + s.dir * s.speed * dt, floor.Position.Y + s.halfH, s.pos.Z)
	end
	local bob = math.abs(math.sin(now * 16)) * 0.08
	s.ap.Position = s.pos + Vector3.new(0, bob, 0)
	s.ao.CFrame = (s.dir > 0 and CFrame.identity or CFrame.Angles(0, math.pi, 0)) * CFrame.Angles(0, 0, math.sin(now * 16) * 0.04)
	s.keyAngle += dt * 3
end

function species.WindupMouse.stomp(model, s, player)
	local hrp = hrpOf(player)
	mouseFlip(model, s, hrp and (model.PrimaryPart.Position.X >= hrp.Position.X and 1 or -1) or 0)
end
function species.WindupMouse.slap(model, s, player, dir)
	mouseFlip(model, s, dir)
end

---------------------------------------------------------------- Jack-in-the-box
-- model parts: Root (the box, a platform), Lid (hinged at its back edge, a platform), Head + Spring (hidden inside)
species.JackInTheBox = {}
function species.JackInTheBox.init(model, s)
	local root = model.PrimaryPart
	root.Anchored = true
	s.lid = model:FindFirstChild("Lid")
	s.head = model:FindFirstChild("Head")
	s.spring = model:FindFirstChild("Spring")
	s.lidCF = s.lid.CFrame
	s.headCF = s.head.CFrame
	s.springCF = s.spring.CFrame
	s.springSize = s.spring.Size
	s.phase, s.t0 = "idle", 0
	s.reach = model:GetAttribute("Reach") or 7
	s.height = model:GetAttribute("PopHeight") or 6
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	s.head.CanCollide = false
	s.spring.CanCollide = false
	model:SetAttribute("Harmless", true) -- the box itself doesn't hurt; the pop does
end

local function onLid(s, pos)
	local rel = s.lidCF:PointToObjectSpace(pos - Vector3.new(0, 3, 0))
	return math.abs(rel.X) < s.lid.Size.X / 2 + 0.5 and rel.Y > -0.5 and rel.Y < 2.2 and math.abs(rel.Z) < s.lid.Size.Z / 2 + 1
end

function species.JackInTheBox.step(model, s, dt, now)
	local root = model.PrimaryPart
	local t = now - s.t0
	local box = root.Position
	if s.phase == "idle" then
		for _, p in ipairs(Players:GetPlayers()) do
			local hrp = hrpOf(p)
			if hrp then
				local d = hrp.Position - box
				if math.abs(d.X) < s.reach and d.Y > -4 and d.Y < 9 and math.abs(d.Z) < 3 then
					s.phase, s.t0 = "wind", now
					Util.playAt(box, "WindUp", 0.55, 1.5)
					break
				end
			end
		end
	elseif s.phase == "wind" then
		-- the box trembles, the crank turns: a clear tell
		local shake = math.sin(now * 60) * 0.06
		for _, part in ipairs({ s.lid }) do
			part.CFrame = s.lidCF * CFrame.new(shake, 0, 0)
		end
		if t > (model:GetAttribute("WindTime") or 0.8) then
			s.phase, s.t0 = "pop", now
			Util.playAt(box, "PopUp", 0.8, 1)
			Util.playAt(box, "Whoosh", 0.5, 1.3)
			for _, p in ipairs(Players:GetPlayers()) do
				local hrp = hrpOf(p)
				if hrp then
					if onLid(s, hrp.Position) then
						Launch:Fire(p, model:GetAttribute("LaunchSpeed") or 74, 0)
					else
						local d = hrp.Position - box
						if math.abs(d.X) < root.Size.X / 2 + 2.4 and d.Y > -3 and d.Y < s.height + 2 and math.abs(d.Z) < 3 then
							HurtPlayer:Fire(p, box, 26, 24)
						end
					end
				end
			end
		end
	elseif s.phase == "pop" then
		local k = math.min(1, t / 0.12)
		local wob = (t > 0.12) and math.sin(t * 18) * math.exp(-t * 3) * 0.5 or 0
		local hinge = s.lidCF * CFrame.new(0, 0, -s.lid.Size.Z / 2)
		s.lid.CFrame = hinge * CFrame.Angles(math.rad(-110 * k), 0, 0) * CFrame.new(0, 0, s.lid.Size.Z / 2)
		local rise = s.height * k + wob
		s.head.CFrame = s.headCF + Vector3.new(0, rise, 0)
		s.spring.Size = Vector3.new(s.springSize.X, s.springSize.Y + rise, s.springSize.Z)
		s.spring.CFrame = s.springCF + Vector3.new(0, rise / 2, 0)
		if t > 1.8 then
			s.phase, s.t0 = "close", now
		end
	elseif s.phase == "close" then
		local k = 1 - math.min(1, t / 0.5)
		local hinge = s.lidCF * CFrame.new(0, 0, -s.lid.Size.Z / 2)
		s.lid.CFrame = hinge * CFrame.Angles(math.rad(-110 * k), 0, 0) * CFrame.new(0, 0, s.lid.Size.Z / 2)
		s.head.CFrame = s.headCF + Vector3.new(0, s.height * k, 0)
		s.spring.Size = Vector3.new(s.springSize.X, s.springSize.Y + s.height * k, s.springSize.Z)
		s.spring.CFrame = s.springCF + Vector3.new(0, s.height * k / 2, 0)
		if t > 0.5 then
			s.lid.CFrame = s.lidCF
			Util.playAt(box, "WoodKnock", 0.4, 1.3)
			s.phase, s.t0 = "rest", now
		end
	elseif s.phase == "rest" then
		if t > (model:GetAttribute("Rest") or 1.6) then
			s.phase = "idle"
		end
	end
end

---------------------------------------------------------------- registry
local function add(model)
	if state[model] or not model:IsDescendantOf(workspace) then
		return
	end
	local sp = species[model:GetAttribute("Species")]
	if not (sp and model.PrimaryPart) then
		return
	end
	local s = {}
	state[model] = s
	sp.init(model, s)
end
for _, m in ipairs(CollectionService:GetTagged("Critter")) do
	add(m)
end
CollectionService:GetInstanceAddedSignal("Critter"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Critter"):Connect(function(m)
	state[m] = nil
end)

CritterStomped.Event:Connect(function(model, player)
	local s = state[model]
	local sp = s and species[model:GetAttribute("Species")]
	if sp and sp.stomp then
		sp.stomp(model, s, player)
	end
end)

Slapped.Event:Connect(function(part, player, dir)
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not CollectionService:HasTag(model, "Critter") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	local s = model and state[model]
	local sp = s and species[model:GetAttribute("Species")]
	if sp and sp.slap then
		sp.slap(model, s, player, dir)
	end
end)

local filterAt = 0
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	if now > filterAt then
		filterAt = now + 1
		refreshRayFilter()
	end
	for model, s in pairs(state) do
		if model.Parent and model.PrimaryPart then
			local ok, err = pcall(species[model:GetAttribute("Species")].step, model, s, dt, now)
			if not ok then
				warn("[Critters] " .. model:GetFullName() .. ": " .. tostring(err))
				state[model] = nil
			end
		end
	end
end)
