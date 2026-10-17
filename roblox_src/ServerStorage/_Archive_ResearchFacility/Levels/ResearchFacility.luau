-- Level: The Research Facility
-- Built entirely from LevelKit pieces. Re-run the build (see ServerStorage.BuildLevel) after editing.
-- Lanes: 1 = foreground (Z 0), 2 = middle (Z -12), 3 = background (Z -24).

return function(Kit)
	local b = Kit.new("ResearchFacility", workspace)
	local P = Kit.PALETTE
	local ALL = { 1, 2, 3 }
	local M = Enum.Material
	local ASPHALT = Color3.fromRGB(58, 60, 66)
	local WALL = Color3.fromRGB(176, 182, 190)
	local LAB = Color3.fromRGB(226, 232, 236)

	local function tip(x, y, z, text, w)
		local p = b:decor({ size = Vector3.new(w or 16, 3, 0.2), pos = Vector3.new(x, y, z), transparency = 1, name = "Tip" })
		b:sign(p, text, Enum.NormalId.Back, Color3.fromRGB(255, 240, 180))
		return p
	end

	local function title(x, y, z, text)
		local p = b:decor({ size = Vector3.new(26, 4, 0.4), pos = Vector3.new(x, y, z), color = P.dark, material = M.Metal, name = "SectionSign" })
		b:sign(p, text, Enum.NormalId.Back, P.cyan)
		return p
	end

	---------------------------------------------------------------- 1. LOADING BAY
	b:section("1_LoadingBay")
	b:platform(ALL, -20, 56, 0, { thick = 4, color = ASPHALT, material = M.Asphalt, trim = false, name = "Yard" })
	b:block(ALL, -22, -20, 0, 120, { transparency = 1, name = "Boundary" })
	b:checkpoint(1, 2, 0, 0)
	title(10, 22, -31, "LOADING BAY")
	tip(2, 9, -4, "A / D  move     SPACE  jump")

	-- lane shift zone teaches depth movement
	b:shiftZone(ALL, 6, 11, 0, 12)
	tip(8.5, 13, -10, "Glowing zone:  W / S  change plane", 18)

	-- stacked crates block the way
	b:crate(1, 17, 0, 4, 1)
	b:crate(1, 17, 4, 4, 1)
	b:bubbleRow(1, 15, 21, 11, 3)
	tip(18, 15, -4, "Walk into crates to push them")

	-- low platform with a movable box
	b:platform(1, 24, 40, 4, { thick = 4, color = P.concrete, material = M.Concrete })
	b:crate(1, 33, 4, 5, 2)
	b:bubbleRow(1, 26, 38, 7, 4)
	b:bubbleRow(1, 31, 36, 16.5, 3) -- stand on the box to reach these
	tip(32, 20, -4, "E  grab / pull     push the box to the dock wall", 22)

	-- container in the middle plane hides a secret in the background plane
	local cont = b:block(2, 17, 33, 0, 9, { color = Color3.fromRGB(40, 90, 150), material = M.CorrodedMetal, fade = true, name = "ShippingContainer" })
	b:block(2, 17, 33, 9, 9.4, { color = Color3.fromRGB(30, 70, 120), material = M.Metal, fade = true, name = "ContainerLid" })
	b:secret(3, 25, 2.5)
	b:bubbleRow(3, 14, 34, 2.5, 5)
	b:bubbleRow(2, 12, 15, 2.5, 2)

	b:shiftZone(ALL, 45, 54, 0, 12)

	-- the dock (high ledge)
	b:block(ALL, 56, 90, -4, 11, { color = P.concrete, material = M.Concrete, name = "Dock" })
	b:decor({ size = Vector3.new(34, 0.4, 0.3), pos = Vector3.new(73, 10.8, 5.1), color = P.hazardYellow, material = M.Neon, name = "Trim" })
	b:bubbleRow(1, 60, 86, 13.5, 6)
	tip(70, 18, -4, "Jump at a ledge to grab it  •  SPACE climbs", 22)

	-- truck + facility backdrop
	b:decor({ size = Vector3.new(30, 12, 9), pos = Vector3.new(30, 6, -40), color = Color3.fromRGB(220, 220, 225), material = M.Metal, name = "Truck" })
	b:decor({ size = Vector3.new(8, 9, 9), pos = Vector3.new(49, 4.5, -40), color = Color3.fromRGB(190, 40, 40), material = M.Metal, name = "TruckCab" })

	---------------------------------------------------------------- 2. MACHINERY HALL
	b:section("2_MachineryHall")
	title(130, 40, -29.6, "MACHINERY HALL")
	b:platform(ALL, 90, 118, 11, { thick = 1.5, name = "CatwalkA" })
	b:checkpoint(1, 100, 11, 1)
	b:block(ALL, 90, 185, -24, -16, { color = P.dark, material = M.Metal, name = "PitFloor" })
	b:hazard(ALL, 90, 185, -16, -12, { color = Color3.fromRGB(110, 255, 90), name = "ToxicSludge", transparency = 0.15 })
	for x = 95, 175, 20 do
		b:decor({ size = Vector3.new(1.5, 28, 1.5), pos = Vector3.new(x, -3, 4), color = P.dark, material = M.Metal, name = "Support" })
	end

	b:swing(1, 134, 45, 26, { style = "container", idle = 28, name = "CargoContainer" })
	b:decor({ size = Vector3.new(70, 2, 3), pos = Vector3.new(134, 46.5, 0), color = P.hazardYellow, material = M.Metal, name = "CraneRail" })
	b:bubbleArc(1, 134, 45, 32.7, -35, 35, 7)
	tip(104, 20, -4, "Jump into the container to grab it  •  SPACE lets go", 26)

	b:platform(ALL, 150, 178, 11, { thick = 1.5, name = "CatwalkB" })
	b:bubbleRow(2, 154, 174, 13.5, 4)
	b:bubbleRow(3, 154, 174, 13.5, 4)
	b:shiftZone(ALL, 152, 158, 11, 10)
	-- steps down to the building entrance
	b:block(1, 178, 181, 0, 7.5, { color = P.steel, material = M.DiamondPlate, name = "Step" })
	b:block(1, 181, 184, 0, 4, { color = P.steel, material = M.DiamondPlate, name = "Step" })

	-- background machinery
	b:block(ALL, 90, 185, -24, 52, { zFront = -30, zBack = -33, color = Color3.fromRGB(46, 50, 60), material = M.Metal, name = "HallBackWall" })
	for i, x in ipairs({ 100, 128, 160 }) do
		b:decor({ shape = Enum.PartType.Cylinder, size = Vector3.new(2, 18, 18), cframe = CFrame.new(x, 24, -29) * CFrame.Angles(0, math.rad(90), 0), color = Color3.fromRGB(90, 96, 110), material = M.Metal, name = "Gear" })
		b:decor({ shape = Enum.PartType.Cylinder, size = Vector3.new(2.2, 4, 4), cframe = CFrame.new(x, 24, -28.8) * CFrame.Angles(0, math.rad(90), 0), color = P.cyan, material = M.Neon, name = "GearHub" })
	end
	for x = 108, 176, 17 do
		b:decor({ size = Vector3.new(4, 30, 4), pos = Vector3.new(x, 5, -29.5), color = Color3.fromRGB(120, 70, 40), material = M.CorrodedMetal, name = "Pipe" })
	end
	b:light(Vector3.new(110, 30, -10), Color3.fromRGB(255, 200, 140), 40, 1.2)
	b:light(Vector3.new(160, 30, -10), Color3.fromRGB(255, 200, 140), 40, 1.2)
	b:light(Vector3.new(134, -8, -10), Color3.fromRGB(110, 255, 90), 40, 2)

	---------------------------------------------------------------- 3. RESEARCH BUILDING (ground + second floor)
	b:section("3_ResearchBuilding")
	title(240, 62, -29.6, "RESEARCH BUILDING")
	b:platform(ALL, 178, 302, 0, { thick = 4, color = LAB, material = M.Marble, trim = false, name = "GroundFloor" })
	-- shell: left wall with doorway in the foreground plane, back wall, right wall
	b:block(1, 183, 185, 10, 56, { color = WALL, material = M.Concrete, name = "LeftWall" })
	b:block({ 2, 3 }, 183, 185, 0, 56, { color = WALL, material = M.Concrete, name = "LeftWall" })
	b:block(ALL, 183, 302, 0, 56, { zFront = -30, zBack = -32, color = Color3.fromRGB(150, 158, 168), material = M.Concrete, name = "BackWall" })
	b:block(ALL, 300, 302, 0, 54, { color = WALL, material = M.Concrete, name = "RightWall" })
	for fy = 4, 46, 14 do
		b:decor({ size = Vector3.new(110, 5, 0.3), pos = Vector3.new(242, fy + 3, -29.8), color = Color3.fromRGB(120, 200, 255), material = M.Glass, transparency = 0.3, name = "Window" })
	end
	b:checkpoint(1, 190, 0, 2)
	b:shiftZone(ALL, 188, 198, 0, 12)
	tip(193, 11, -4, "Rooms overlap - check which plane a path is on", 22)
	b:crate(1, 206, 0, 4, 1)

	-- middle-plane lab equipment (solid on both lower floors) with a glass chamber
	b:block(2, 200, 222, 0, 24, { color = Color3.fromRGB(200, 206, 214), material = M.Metal, fade = true, name = "LabEquipment" })
	b:block(2, 222, 234, 0, 12, { color = Color3.fromRGB(150, 230, 255), material = M.Glass, transparency = 0.65, fade = true, name = "GlassChamber" })
	b:block(2, 222, 234, 12, 24, { color = Color3.fromRGB(200, 206, 214), material = M.Metal, fade = true, name = "LabEquipment" })
	b:block(2, 234, 255, 0, 24, { color = Color3.fromRGB(200, 206, 214), material = M.Metal, fade = true, name = "LabEquipment" })
	for x = 204, 250, 8 do
		if x < 220 or x > 236 then
			b:decor({ size = Vector3.new(3, 1.2, 0.2), pos = Vector3.new(x, 7, -6.9), color = (x % 16 == 4) and P.green or P.cyan, material = M.Neon, name = "Indicator" })
		end
	end

	-- background laboratory (ground floor): secret behind the glass + gate lever
	b:secret(3, 228, 2.5)
	b:lever(3, 246, 0, "LabGate", { label = "GATE" })
	for x = 204, 240, 12 do
		b:decor({ size = Vector3.new(5, 3, 3), pos = Vector3.new(x, 1.5, -28), color = LAB, material = M.SmoothPlastic, name = "LabBench" })
		b:decor({ shape = Enum.PartType.Cylinder, size = Vector3.new(3, 1.6, 1.6), cframe = CFrame.new(x, 4.5, -28) * CFrame.Angles(0, 0, math.rad(90)), color = P.green, material = M.Neon, transparency = 0.3, name = "Specimen" })
	end
	b:bubbleRow(3, 200, 220, 2.5, 4)
	b:light(Vector3.new(228, 10, -24), P.cyan, 24, 2)
	b:shiftZone(ALL, 255, 261, 0, 12)

	-- security gate
	b:door(1, 262, 264, 0, 13, "LabGate", "Up", { name = "SecurityGate" })
	b:block(1, 262, 264, 13, 14, { color = P.dark, name = "GateHeader" })
	b:block({ 2, 3 }, 262, 264, 0, 14, { color = WALL, material = M.Concrete, name = "GateWall" })
	tip(250, 10, -4, "The gate switch is in the back lab", 18)

	-- after the gate: stairs up in the background plane
	b:shiftZone(ALL, 265, 271, 0, 12)
	b:block(3, 272, 277, 0, 3.5, { color = P.steel, material = M.DiamondPlate, name = "Stair" })
	b:block(3, 277, 282, 0, 7, { color = P.steel, material = M.DiamondPlate, name = "Stair" })
	b:block(3, 282, 287, 0, 10.5, { color = P.steel, material = M.DiamondPlate, name = "Stair" })
	b:bubbleRow(1, 268, 296, 2.5, 5)

	-- SECOND FLOOR (Y 14)
	b:platform(ALL, 287, 300, 14, { thick = 1, name = "Floor2Landing" })
	b:checkpoint(1, 296, 14, 3)
	b:shiftZone(ALL, 288, 299, 14, 12)
	-- foreground catwalk with a jump gap
	b:platform(1, 240, 287, 14, { thick = 1, name = "Floor2Catwalk" })
	b:platform(1, 196, 232, 14, { thick = 1, name = "Floor2Catwalk" })
	b:bubbleArc(1, 236, 22, 5, -60, 60, 3)
	-- junction where the two routes split
	b:platform({ 2, 3 }, 255, 262, 14, { thick = 1, name = "Floor2Junction" })
	b:shiftZone(ALL, 255, 262, 14, 12)
	-- background route behind the lab equipment
	b:platform(3, 200, 255, 14, { thick = 1, name = "Floor2RearRoute" })
	b:bubbleRow(3, 204, 250, 16.5, 7)
	b:secret(3, 212, 17)
	b:light(Vector3.new(225, 22, -24), Color3.fromRGB(255, 120, 220), 20, 1.5)
	-- left landing + elevator
	b:platform(1, 194, 200, 14, { thick = 1, name = "Floor2LeftLanding" })
	b:platform({ 2, 3 }, 186, 200, 14, { thick = 1, name = "Floor2LeftLanding" })
	b:shiftZone(ALL, 194, 200, 14, 12)
	b:mover(1, 188, 194, 14, Vector3.new(0, 14, 0), { mode = "Loop", speed = 6, wait = 2, name = "Elevator" })
	tip(191, 24, -4, "Ride the lift", 8)

	---------------------------------------------------------------- 4. CONTAINMENT CHAMBER (third floor, Y 28)
	b:section("4_ContainmentChamber")
	b:platform(ALL, 194, 258, 28, { thick = 1, name = "Floor3" })
	b:checkpoint(1, 199, 28, 4)
	b:shiftZone(ALL, 196, 203, 28, 12)
	tip(215, 38, -4, "Pull the HEAVY crate onto the plate", 18)
	b:crate(1, 208, 28, 5, 3)
	b:plate(1, 236, 28, 3, "ChamberDoor")
	b:door(1, 246, 248, 28, 41, "ChamberDoor", "Up", { name = "SealedDoor" })
	b:block({ 2, 3 }, 246, 248, 28, 41, { color = WALL, material = M.Concrete, name = "ChamberWall" })
	for x = 210, 240, 10 do
		b:decor({ shape = Enum.PartType.Cylinder, size = Vector3.new(12, 6, 6), cframe = CFrame.new(x, 34, -36) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(120, 255, 200), material = M.Glass, transparency = 0.4, name = "ContainmentTube" })
	end

	-- co-op vault: two plates on different planes must be pressed at the same time
	b:crate(2, 204, 28, 4, 1)
	b:plate(2, 214, 28, 1, "Vault")
	b:plate(3, 222, 28, 1, "Vault")
	b:door(3, 234, 235.5, 28, 41, "Vault", "Up", { name = "VaultDoor" })
	b:secret(3, 241, 31)
	b:light(Vector3.new(241, 34, -24), Color3.fromRGB(255, 120, 220), 14, 2)
	tip(218, 38, -16, "CO-OP: hold both plates at once", 16)

	-- timed bridge over the energy field
	b:lever(1, 253, 28, "Bridge", { mode = "Timed", time = 7, label = "BRIDGE" })
	b:block(ALL, 258, 278, 20, 21, { color = P.dark, material = M.Metal, name = "FieldEmitter" })
	b:hazard(ALL, 258, 278, 21, 23, { color = Color3.fromRGB(255, 60, 200), name = "EnergyField" })
	b:mover(1, 258, 278, 22.5, Vector3.new(0, 5.5, 0), { mode = "Channel", channel = "Bridge", speed = 16, name = "TimedBridge", color = Color3.fromRGB(255, 160, 40) })
	tip(266, 38, -4, "Hurry - the bridge resets!", 14)

	-- far landing, shortcut hatch, steps up
	b:platform({ 2, 3 }, 278, 300, 28, { thick = 1, name = "Floor3FarLanding" })
	b:platform(1, 278, 281, 28, { thick = 1, name = "Floor3FarLanding" })
	b:platform(1, 286, 300, 28, { thick = 1, name = "Floor3FarLanding" })
	b:door(1, 281, 286, 27, 28, "Shortcut", "Left", { name = "ShortcutHatch", color = P.hazardYellow })
	b:lever(1, 279.2, 28, "Shortcut", { label = "SHORTCUT" })
	b:bubbleRow(1, 262, 274, 31, 4)
	b:block(1, 287, 293, 28, 33, { color = P.steel, material = M.DiamondPlate, name = "Step" })
	b:block(1, 293, 300, 28, 38, { color = P.steel, material = M.DiamondPlate, name = "Step" })

	---------------------------------------------------------------- 4b. MACHINERY ROOM (fourth floor, Y 42)
	b:section("4b_MachineryRoom")
	b:platform(ALL, 196, 292, 42, { thick = 1, name = "Floor4" })
	b:checkpoint(1, 286, 42, 5)
	-- piston crushers (timing)
	b:block({ 2, 3 }, 240, 275, 42, 54, { color = Color3.fromRGB(70, 76, 88), material = M.Metal, fade = true, name = "Machinery" })
	b:mover(1, 262, 268, 54, Vector3.new(0, -7.5, 0), { mode = "Loop", speed = 14, wait = 1.2, hazard = true, name = "Crusher", color = Color3.fromRGB(200, 60, 50), thick = 4 })
	b:mover(1, 247, 253, 54, Vector3.new(0, -7.5, 0), { mode = "Loop", speed = 14, wait = 1.2, phase = 0.5, hazard = true, name = "Crusher", color = Color3.fromRGB(200, 60, 50), thick = 4 })
	b:block(1, 240, 275, 54, 56, { color = P.dark, material = M.Metal, name = "CrusherHousing" })
	tip(258, 52, -8, "Time your run past the crushers", 16)

	-- sequence switches open a cabinet in the middle plane
	local hint = b:decor({ size = Vector3.new(14, 4, 0.3), pos = Vector3.new(230, 50, -29.5), color = P.dark, material = M.Metal, name = "SequenceHint" })
	b:sign(hint, "ORDER:  B  >  C  >  A", Enum.NormalId.Back, P.green)
	b:lever(1, 224, 42, "SeqVault", { mode = "Sequence", group = "SeqVault", order = 3, label = "A" })
	b:lever(1, 230, 42, "SeqVault", { mode = "Sequence", group = "SeqVault", order = 1, label = "B" })
	b:lever(1, 236, 42, "SeqVault", { mode = "Sequence", group = "SeqVault", order = 2, label = "C" })
	b:block(2, 196, 199, 42, 51, { color = P.steel, material = M.Metal, name = "CabinetWall" })
	b:block(2, 196, 216, 50, 51, { color = P.steel, material = M.Metal, name = "CabinetLid" })
	b:door(2, 215, 216, 42, 50, "SeqVault", "Up", { name = "CabinetDoor" })
	b:secret(2, 206, 45)
	b:shiftZone(ALL, 216, 222, 42, 10)

	-- crane hook used to reach the roof
	b:swing(1, 218, 76, 26, { style = "hook", idle = 10, name = "CraneHook" })
	b:decor({ size = Vector3.new(4, 4, 30), pos = Vector3.new(218, 77.5, -10), color = P.hazardYellow, material = M.Metal, name = "CraneArm" })
	b:decor({ size = Vector3.new(3, 80, 3), pos = Vector3.new(218, 38, -34), color = P.hazardYellow, material = M.Metal, name = "CraneMast" })
	b:bubbleArc(1, 218, 76, 29.6, -50, 50, 7)
	tip(208, 58, -4, "Swing with A / D to build momentum", 18)
	b:light(Vector3.new(230, 50, -10), Color3.fromRGB(255, 200, 140), 40, 1)

	---------------------------------------------------------------- 5. ROOFTOP (Y 56)
	b:section("5_Rooftop")
	title(300, 76, -31, "ROOFTOP")
	b:platform(ALL, 242, 330, 56, { thick = 2, color = Color3.fromRGB(90, 92, 98), material = M.Concrete, name = "Roof" })
	b:block(ALL, 302, 330, 0, 54, { color = Color3.fromRGB(140, 146, 156), material = M.Concrete, name = "Annex" })
	b:checkpoint(1, 248, 56, 6)
	b:shiftZone(ALL, 266, 276, 56, 12)
	-- foreground obstacle: electrified fence
	b:hazard(1, 290, 292, 56, 76, { color = Color3.fromRGB(80, 160, 255), name = "ElectricFence", transparency = 0.3 })
	b:block(1, 288, 290, 56, 76, { color = P.dark, material = M.Metal, name = "FencePost" })
	b:block(1, 292, 294, 56, 76, { color = P.dark, material = M.Metal, name = "FencePost" })
	tip(282, 66, -4, "Blocked! Find another plane", 14)
	-- middle plane: main route
	b:block(2, 300, 306, 56, 60, { color = Color3.fromRGB(180, 184, 190), material = M.Metal, name = "ACUnit" })
	b:bubbleRow(2, 280, 326, 59, 7)
	b:swing(2, 341, 88, 24, { style = "cable", idle = 26, name = "RoofCable" })
	b:decor({ size = Vector3.new(40, 2, 2), pos = Vector3.new(341, 89, -12), color = P.hazardYellow, material = M.Metal, name = "CableArm" })
	b:bubbleArc(2, 341, 88, 27.6, -30, 30, 5)
	-- background plane: optional route with timed lasers + secret + moving platform
	for i, x in ipairs({ 284, 296, 308 }) do
		b:hazard(3, x, x + 1, 56, 66, { interval = 1.3, off = 1.3, offset = i * 0.6, name = "Laser" })
	end
	b:bubbleRow(3, 278, 320, 58.5, 6)
	b:secret(3, 322, 59)
	b:mover(3, 331, 337, 56, Vector3.new(14, 0, 0), { mode = "Loop", speed = 6, wait = 1, name = "RoofShuttle" })
	-- kill zone below the final gap
	b:hazard(ALL, 330, 352, 22, 30, { transparency = 0.9, name = "FallZone" })
	b:decor({ size = Vector3.new(22, 1, 40), pos = Vector3.new(341, 0, -12), color = ASPHALT, material = M.Asphalt, name = "Street" })
	-- exit tower
	b:block(ALL, 352, 372, 0, 58, { color = Color3.fromRGB(120, 130, 145), material = M.Concrete, name = "ExitTower" })
	b:block(ALL, 372, 374, 58, 120, { transparency = 1, name = "Boundary" })
	b:shiftZone(ALL, 353, 359, 58, 12)
	b:exit(2, 364, 58)

	---------------------------------------------------------------- BACKDROP: the laboratory complex
	b:section("Backdrop")
	b:decor({ size = Vector3.new(600, 2, 60), pos = Vector3.new(180, -2, 34), color = ASPHALT, material = M.Asphalt, name = "FrontGround" })
	b:decor({ size = Vector3.new(600, 2, 200), pos = Vector3.new(180, -2, -140), color = Color3.fromRGB(50, 54, 60), material = M.Asphalt, name = "BackGround" })
	local rng = Random.new(7)
	for x = -30, 420, 34 do
		local h = rng:NextInteger(40, 110)
		local z = -70 - rng:NextInteger(0, 40)
		b:decor({ size = Vector3.new(30, h, 24), pos = Vector3.new(x, h / 2, z), color = Color3.fromRGB(70, 78, 92), material = M.Concrete, name = "LabTower" })
		for wy = 8, h - 6, 10 do
			b:decor({ size = Vector3.new(24, 2, 0.4), pos = Vector3.new(x, wy, z + 12.1), color = rng:NextNumber() > 0.5 and P.cyan or Color3.fromRGB(255, 220, 150), material = M.Neon, transparency = rng:NextNumber() * 0.5, name = "Windows" })
		end
	end
	for x = -10, 90, 25 do
		b:decor({ shape = Enum.PartType.Cylinder, size = Vector3.new(26, 10, 10), cframe = CFrame.new(x, 13, -52) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(140, 255, 210), material = M.Glass, transparency = 0.35, name = "ContainmentChamber" })
		b:decor({ shape = Enum.PartType.Cylinder, size = Vector3.new(14, 7, 7), cframe = CFrame.new(x, 9, -52) * CFrame.Angles(0, 0, math.rad(90)), color = P.green, material = M.Neon, transparency = 0.2, name = "Specimen" })
		b:light(Vector3.new(x, 12, -46), P.green, 20, 1.5)
	end

	return b
end
