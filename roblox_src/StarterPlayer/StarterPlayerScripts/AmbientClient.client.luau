-- AmbientClient: local, purely visual motion driven by tags and attributes (the server only flips Active).
--   Spinner: Axis ("X"/"Y"/"Z", in the object's own frame), Speed (rad/s), Active (default true)
--   Bobber:  Amp (studs), Period (s), Phase (0-1), Roll (degrees of gentle rock)
--   Swayer:  Deg (swing degrees), Period (s), Pivot (local offset to the hang point, Vector3)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local base = {}
local angle = {}

local function getCF(inst)
	return inst:IsA("Model") and inst:GetPivot() or inst.CFrame
end
local function setCF(inst, cf)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	else
		inst.CFrame = cf
	end
end

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for _, inst in ipairs(CollectionService:GetTagged("Spinner")) do
		if inst:IsDescendantOf(workspace) then
			base[inst] = base[inst] or getCF(inst)
			local speed = inst:GetAttribute("Speed") or 1
			if inst:GetAttribute("Active") ~= false then
				angle[inst] = (angle[inst] or 0) + speed * dt
			end
			local a = angle[inst] or 0
			local axis = inst:GetAttribute("Axis") or "Z"
			local rot = axis == "X" and CFrame.Angles(a, 0, 0) or (axis == "Y" and CFrame.Angles(0, a, 0) or CFrame.Angles(0, 0, a))
			setCF(inst, base[inst] * rot)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged("Bobber")) do
		if inst:IsDescendantOf(workspace) then
			base[inst] = base[inst] or getCF(inst)
			local w = (t / (inst:GetAttribute("Period") or 3) + (inst:GetAttribute("Phase") or 0)) * math.pi * 2
			local roll = math.rad(inst:GetAttribute("Roll") or 0) * math.sin(w * 0.5)
			setCF(inst, base[inst] * CFrame.new(0, math.sin(w) * (inst:GetAttribute("Amp") or 0.3), 0) * CFrame.Angles(0, 0, roll))
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged("Swayer")) do
		if inst:IsDescendantOf(workspace) then
			base[inst] = base[inst] or getCF(inst)
			local pivot = inst:GetAttribute("Pivot") or Vector3.new(0, 1, 0)
			local w = (t / (inst:GetAttribute("Period") or 4)) * math.pi * 2
			local r = math.rad(inst:GetAttribute("Deg") or 4) * math.sin(w)
			local hinge = base[inst] * CFrame.new(pivot)
			setCF(inst, hinge * CFrame.Angles(0, 0, r) * CFrame.new(-pivot))
		end
	end
end)
