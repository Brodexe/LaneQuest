--!strict
-- Motion: deterministic movers shared by the server and every client.
-- A mover's pose is a pure function of the shared server clock, so the server (which moves props) and each
-- client (which moves the platform under its own character, smoothly) agree without streaming CFrames.
-- Tag "Mover" on a BasePart or Model. Its build pose is kept in the "BaseCF" attribute (set once by the builder).
--   Kind = "Shuttle": base -> base * Offset and back. Offset (CFrame), Period (s), Phase (0-1), Hold (0-0.45, share of
--                      the period spent resting at each end), Ease ("Sine" default, or "Linear").
--   Kind = "Spin":    turns about its own Axis ("X"/"Y"/"Z") at Speed (rad/s), starting at Phase (radians).
--   Kind = "Toggle":  event driven. State true eases base -> base * Offset over Duration, false eases back.
--                      The server writes State, Since (server time) and FromK (progress when it changed).
-- Shuttle and Spin pause while Running == false (the server keeps Clock, the paused-time offset).
local Motion = {}

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

local function now(): number
	return workspace:GetServerTimeNow()
end
Motion.now = now

-- effective clock for looping movers (honours pauses)
local function clock(inst: Instance, t: number): number
	local offset = inst:GetAttribute("Clock") or 0
	if inst:GetAttribute("Running") == false then
		return (inst:GetAttribute("StoppedAt") or t) - offset
	end
	return t - offset
end

function Motion.toggleK(inst: Instance, t: number): number
	local dur = inst:GetAttribute("Duration") or 1
	local since = inst:GetAttribute("Since") or 0
	local from = inst:GetAttribute("FromK") or 0
	local step = (t - since) / dur
	if inst:GetAttribute("State") then
		return math.clamp(from + step, 0, 1)
	else
		return math.clamp(from - step, 0, 1)
	end
end

-- the mover's pose (pivot CFrame) at server time t
function Motion.pose(inst: Instance, t: number): CFrame?
	local base = inst:GetAttribute("BaseCF")
	if typeof(base) ~= "CFrame" then
		return nil
	end
	local kind = inst:GetAttribute("Kind")
	if kind == "Shuttle" then
		local off = inst:GetAttribute("Offset")
		if typeof(off) ~= "CFrame" then
			return base
		end
		local period = inst:GetAttribute("Period") or 4
		local hold = inst:GetAttribute("Hold") or 0
		local u = (clock(inst, t) / period + (inst:GetAttribute("Phase") or 0)) % 1
		-- 0..hold rest at A, hold..0.5 travel, 0.5..0.5+hold rest at B, then travel back
		local k
		if u < hold then
			k = 0
		elseif u < 0.5 then
			k = (u - hold) / (0.5 - hold)
		elseif u < 0.5 + hold then
			k = 1
		else
			k = 1 - (u - 0.5 - hold) / (0.5 - hold)
		end
		if inst:GetAttribute("Ease") ~= "Linear" then
			k = smooth(k)
		end
		return base:Lerp(base * off, k)
	elseif kind == "Spin" then
		local a = (inst:GetAttribute("Phase") or 0) + clock(inst, t) * (inst:GetAttribute("Speed") or 1)
		local axis = inst:GetAttribute("Axis") or "Z"
		local rot = axis == "X" and CFrame.Angles(a, 0, 0) or (axis == "Y" and CFrame.Angles(0, a, 0) or CFrame.Angles(0, 0, a))
		return base * rot
	elseif kind == "Toggle" then
		local off = inst:GetAttribute("Offset")
		if typeof(off) ~= "CFrame" then
			return base
		end
		local k = Motion.toggleK(inst, t)
		if inst:GetAttribute("Ease") ~= "Linear" then
			k = smooth(k)
		end
		return base:Lerp(base * off, k)
	end
	return base
end

-- server helpers ---------------------------------------------------------------
function Motion.setState(inst: Instance, state: boolean)
	if (inst:GetAttribute("State") == true) == state then
		return
	end
	local t = now()
	inst:SetAttribute("FromK", Motion.toggleK(inst, t))
	inst:SetAttribute("Since", t)
	inst:SetAttribute("State", state)
end

function Motion.setRunning(inst: Instance, running: boolean)
	local was = inst:GetAttribute("Running") ~= false
	if was == running then
		return
	end
	local t = now()
	if running then
		local stoppedAt = inst:GetAttribute("StoppedAt") or t
		inst:SetAttribute("Clock", (inst:GetAttribute("Clock") or 0) + (t - stoppedAt))
		inst:SetAttribute("Running", true)
	else
		inst:SetAttribute("StoppedAt", t)
		inst:SetAttribute("Running", false)
	end
end

-- place a mover at time t and give its parts the matching velocity, so whoever stands on it rides along
local DT = 1 / 30
local solidCache = setmetatable({}, { __mode = "k" }) :: { [Instance]: { BasePart } }
local function solids(model: Instance): { BasePart }
	local list = solidCache[model]
	if not list then
		list = {}
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				table.insert(list, p)
			end
		end
		solidCache[model] = list
	end
	return list
end

function Motion.apply(inst: Instance, t: number)
	local cf = Motion.pose(inst, t)
	if not cf then
		return
	end
	local ahead = Motion.pose(inst, t + DT) or cf
	local lin = (ahead.Position - cf.Position) / DT
	local axis, angle = (cf.Rotation:Inverse() * ahead.Rotation):ToAxisAngle()
	local ang = cf.Rotation:VectorToWorldSpace(axis) * (angle / DT)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
		inst.AssemblyLinearVelocity = lin
		inst.AssemblyAngularVelocity = ang
	elseif inst:IsA("Model") then
		inst:PivotTo(cf)
		local pivot = cf.Position
		for _, p in ipairs(solids(inst)) do
			p.AssemblyLinearVelocity = lin + ang:Cross(p.Position - pivot)
			p.AssemblyAngularVelocity = ang
		end
	end
end

return Motion
