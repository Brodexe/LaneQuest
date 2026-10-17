--!strict
-- The Paper Workshop: every tuning value lives here.
-- Coordinates: X = left/right along the level, Y = up, Z = depth. Lane 1 is the front lane.
local Config = {}

-- Depth lanes (Z of each lane centre)
Config.LANES = { 0, -8 }
Config.LANE_SHIFT_TIME = 0.32 -- seconds to slide between lanes

-- Movement
Config.WALK_SPEED = 15
Config.JUMP_HEIGHT = 6.5
Config.GRAVITY = 160
Config.GROUND_ACCEL = 8 -- fraction of full speed gained per second (8 = full speed in ~0.13 s)
Config.GROUND_DECEL = 11
Config.AIR_ACCEL = 4
Config.AIR_DECEL = 1.5
Config.COYOTE_TIME = 0.1 -- grace period to jump after walking off a ledge
Config.JUMP_BUFFER = 0.12 -- a jump pressed this long before landing still counts

-- Camera
Config.CAMERA_DISTANCE = 42
Config.CAMERA_HEIGHT = 4
Config.CAMERA_FOV = 40
Config.CAMERA_LOOKAHEAD = 4
Config.CAMERA_X_SPEED = 5
Config.CAMERA_Y_SPEED = 3
Config.CAMERA_Y_DEADZONE = 2
Config.CAMERA_LANE_SPEED = 3
Config.CAMERA_MIN_X = 14
Config.CAMERA_MAX_X = 122

-- Grab / carry / throw
Config.GRAB_RANGE = 2.4 -- gap between you and the object's edge
Config.HOLD_GAP = 1.4 -- held object's edge sits this far in front of you
Config.HOLD_HEIGHT = 0.6
Config.THROW_SPEED = 36
Config.THROW_UP = 20

-- Slap
Config.SLAP_RANGE = 3.6
Config.SLAP_COOLDOWN = 0.45
Config.SLAP_SPEED = 13 -- velocity change given to a slapped prop
Config.SLAP_UP = 7

-- Ragdoll and recovery
Config.RAGDOLL_FALL_SPEED = 78 -- landing faster than this floors you (about a 19-stud drop)
Config.RAGDOLL_PROP_SPEED = 30 -- a prop moving this fast knocks you over
Config.RAGDOLL_DURATION = 1.7
Config.RAGDOLL_COOLDOWN = 1.2
Config.SELF_DESTRUCT_TIME = 1.6
Config.KILL_Y = -4
Config.RESPAWN_DELAY = 1.1
Config.PROP_RESET_Y = -6

-- Boss: the Wind-Up Workshop Beetle
Config.BEETLE_TRIGGER_RANGE = 15
Config.BEETLE_TELEGRAPH_TIME = 0.9
Config.BEETLE_CHARGE_DISTANCE = 7
Config.BEETLE_CHARGE_TIME = 0.55
Config.BEETLE_DIZZY_TIME = 1.2
Config.BEETLE_RETURN_TIME = 2.4
Config.BEETLE_COOLDOWN = 2.2
Config.BEETLE_STAGGER_SPEED = 15 -- prop impact speed that staggers it
Config.BEETLE_STAGGER_TIME = 2.6
Config.BEETLE_KNOCKBACK = Vector3.new(-22, 26, 0)
Config.BEETLE_MIN_X = 109 -- its centre never goes further left than this

-- Audio (Roblox-licensed APM Music / Pro Sound Effects)
Config.MUSIC_VOLUME = 0.22
Config.Sounds = {
	Music = "rbxassetid://1837383236", -- "Hear You Singing" (APM)
	MusicBox = "rbxassetid://9043210091", -- "Music Box 5" (APM)
	Cardboard = "rbxassetid://9113720176",
	CardboardRub = "rbxassetid://9113578742",
	Wood = "rbxassetid://9126267420",
	WoodKnock = "rbxassetid://9120918417",
	Fabric = "rbxassetid://9114883390",
	Metal = "rbxassetid://9116649188",
	Slap = "rbxassetid://9120978251",
	Whoosh = "rbxassetid://9119738654",
	BodyFall = "rbxassetid://9113480917",
	WindUp = "rbxassetid://9120225609",
	Ratchet = "rbxassetid://9117611663",
	PopUp = "rbxassetid://9113578628",
	HubMusic = "rbxassetid://1840285037", -- "Passing Fancy (A)" (APM)
	ArchiveMusic = "rbxassetid://9042152099", -- "Peaceful Grace (c)" (APM)
	ArchiveDrips = "rbxassetid://9112893185",
	Splash = "rbxassetid://9117947034",
	PageTurn = "rbxassetid://9118835414",
	PaperRustle = "rbxassetid://9125723913",
	WoodCreak = "rbxassetid://9120839174",
	GlassTink = "rbxassetid://9114619050",
	GearClick = "rbxassetid://9118203389",
}
Config.IMPACT_SOUND_SPEED = 12
Config.IMPACT_SOUND_COOLDOWN = 0.25

function Config.nearestLane(z: number): number
	local best, bestD = 1, math.huge
	for i, lz in ipairs(Config.LANES) do
		local d = math.abs(z - lz)
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

return Config
