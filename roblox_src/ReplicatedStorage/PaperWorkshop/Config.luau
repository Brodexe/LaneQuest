--!strict
-- The Paper Workshop: every tuning value lives here.
-- Coordinates: X = left/right along the level, Y = up, Z = depth. Lane 1 is the front lane.
local Config = {}

-- Depth layers (Z of each layer centre): front, middle, back. W/S steps between neighbours.
Config.LANES = { 0, -4, -8 }
Config.LANE_GAP = 4
Config.LANE_PULL = 0.9 -- how hard the body is steered onto its layer (1 = full walk speed per stud off)
Config.LAYER_BUFFER = 0.25 -- a layer step pressed this long before it's possible still happens
Config.LAYER_FLOOR_REACH = 3.5 -- standing still, you only step into a layer with floor this close below your feet

-- Movement
Config.WALK_SPEED = 15
Config.JUMP_HEIGHT = 6.5
Config.GRAVITY = 160
Config.GROUND_ACCEL = 12 -- fraction of full speed gained per second (12 = full speed in ~0.08 s)
Config.GROUND_DECEL = 16
Config.AIR_ACCEL = 7
Config.AIR_DECEL = 5
Config.COYOTE_TIME = 0.1 -- grace period to jump after walking off a ledge
Config.JUMP_BUFFER = 0.12 -- a jump pressed this long before landing still counts
Config.JUMP_CUT = 0.5 -- letting go of jump while rising keeps this much of the upward speed (short hop)
Config.FALL_GRAVITY = 1.5 -- falling pulls this many times harder than rising
Config.MAX_FALL_SPEED = 120
Config.STEP_UP = 1.1 -- lips this low are stepped onto instead of blocking you

-- Camera
Config.CAMERA_DISTANCE = 36
Config.CAMERA_HEIGHT = 6
Config.CAMERA_AIM_HEIGHT = 1.5 -- looks slightly down at the play layers
Config.CAMERA_FOV = 48
Config.DOF_FAR = 0.32
Config.DOF_NEAR = 0.18
Config.DOF_RADIUS = 9
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
Config.RAGDOLL_FALL_SPEED = 95 -- landing faster than this floors you (about a 19-stud drop with the heavier fall)
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
