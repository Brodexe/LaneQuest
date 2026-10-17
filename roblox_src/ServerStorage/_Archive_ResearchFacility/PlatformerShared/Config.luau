--!strict
-- Shared configuration for the 2.5D lane platformer.
local Config = {}

-- Playable depth planes (lanes). Index 1 = foreground, 3 = background.
Config.LANE_Z = { 0, -12, -24 }
Config.LANE_NAMES = { "Foreground", "Middle", "Background" }
Config.LANE_DEPTH = 10 -- Z thickness of a single-lane platform

-- Movement tuning
Config.WALK_SPEED = 16
Config.JUMP_HEIGHT = 7.5
Config.LANE_SHIFT_SPEED = 55 -- studs/sec while moving between planes
Config.GRAB_RANGE = 3.2 -- horizontal gap allowed between player and crate
Config.SWING_CATCH_RADIUS = 4.5
Config.SWING_PUMP = 2.2 -- rad/s^2 from left/right input while swinging
Config.SWING_RELEASE_BOOST = 20
Config.LEDGE_COOLDOWN = 0.4

-- Camera
Config.CAMERA_DISTANCE = 54
Config.CAMERA_HEIGHT = 7
Config.CAMERA_FOV = 45

-- Scoring
Config.BUBBLE_VALUE = 10
Config.SECRET_VALUE = 100

-- Unlockable costumes (materials + colors + trail). Requirements are checked on the server.
Config.COSTUMES = {
	{ id = "LabCoat", name = "Lab Coat", color = Color3.fromRGB(235, 238, 242), material = Enum.Material.SmoothPlastic, trail = nil, req = { score = 0 } },
	{ id = "Hazmat", name = "Hazmat Orange", color = Color3.fromRGB(255, 140, 30), material = Enum.Material.Fabric, trail = Color3.fromRGB(255, 170, 60), req = { score = 200 } },
	{ id = "Circuit", name = "Circuit Neon", color = Color3.fromRGB(40, 220, 255), material = Enum.Material.Neon, trail = Color3.fromRGB(60, 230, 255), req = { score = 500 } },
	{ id = "Chrome", name = "Chrome Prototype", color = Color3.fromRGB(200, 205, 215), material = Enum.Material.Foil, trail = Color3.fromRGB(220, 220, 255), req = { completed = true } },
	{ id = "Golden", name = "Golden Specimen", color = Color3.fromRGB(255, 200, 40), material = Enum.Material.Glass, trail = Color3.fromRGB(255, 220, 80), req = { secrets = "all" } },
}

function Config.laneZ(lane: number): number
	return Config.LANE_Z[lane] or 0
end

function Config.nearestLane(z: number): number
	local best, bestD = 1, math.huge
	for i, lz in ipairs(Config.LANE_Z) do
		local d = math.abs(z - lz)
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

return Config
