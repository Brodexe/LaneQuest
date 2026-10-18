--!strict
-- Areas: the three connected places in this one Roblox place, laid side by side on the same lane planes.
-- Each area lives under its own model in Workspace and keeps named spawn parts in a "Spawns" folder.
local Areas = {}

Areas.List = {
	Demo = {
		root = "PaperWorkshop",
		camMinX = 14,
		camMaxX = 122,
		camMaxXOpen = 150, -- once the hidden passage behind the exit box is open
		killY = -4,
		defaultSpawn = "Start",
		lighting = "Demo",
		music = "Music",
	},
	Hub = {
		root = "Loomworks",
		camMinX = 322,
		camMaxX = 446,
		killY = 0,
		defaultSpawn = "Arrival",
		lighting = "Hub",
		music = "HubMusic",
	},
	Archive = {
		root = "DrownedArchive",
		camMinX = 700,
		camMaxX = 836,
		killY = -6,
		defaultSpawn = "Entry",
		lighting = "Archive",
		music = "ArchiveMusic",
		ambience = "ArchiveDrips",
	},
}

-- Heartloom connections. A new world = one more entry here, plus its entrance model and socket in the hub.
Areas.Connections = {
	{ id = "Archive", area = "Archive", entrance = "ArchiveEntrance", socket = "Socket_Archive", arriveSpawn = "FromArchive" },
}

-- Client-side lighting moods (applied while the travel curtain is closed).
Areas.Lighting = {
	Demo = { Brightness = 2, Ambient = Color3.fromRGB(118, 102, 86), OutdoorAmbient = Color3.fromRGB(150, 128, 106), Tint = Color3.fromRGB(255, 244, 228), Saturation = 0.05, Contrast = 0.04 },
	Hub = { Brightness = 1.35, Ambient = Color3.fromRGB(98, 80, 62), OutdoorAmbient = Color3.fromRGB(124, 100, 78), Tint = Color3.fromRGB(255, 236, 210), Saturation = 0, Contrast = 0.1 },
	Archive = { Brightness = 1.25, Ambient = Color3.fromRGB(74, 90, 94), OutdoorAmbient = Color3.fromRGB(98, 118, 122), Tint = Color3.fromRGB(222, 236, 234), Saturation = -0.22, Contrast = 0.06 },
}

function Areas.get(name: string?)
	return Areas.List[name or "Demo"] or Areas.List.Demo
end

-- Camera X limits where the player stands. An area may carry camBands: { {x0, x1, y0, y1, minX, maxX}, ... };
-- the first band containing the position wins, otherwise the area's own camMinX/camMaxX apply.
function Areas.camBounds(area, pos: Vector3, map: Instance?): (number, number)
	if area.camBands then
		for _, b in ipairs(area.camBands) do
			if pos.X >= b[1] and pos.X <= b[2] and pos.Y >= b[3] and pos.Y <= b[4] then
				return b[5], b[6]
			end
		end
	end
	local maxX = (area.camMaxXOpen and map and map:GetAttribute("PassageOpen")) and area.camMaxXOpen or area.camMaxX
	return area.camMinX, maxX
end

-- The spawn part for an area (falls back to the area's default, then to the demo start).
function Areas.spawnPart(areaName: string?, spawnName: string?): BasePart?
	local area = Areas.get(areaName)
	local root = workspace:FindFirstChild(area.root)
	local spawns = root and root:FindFirstChild("Spawns")
	local part = spawns and (spawns:FindFirstChild(spawnName or "") or spawns:FindFirstChild(area.defaultSpawn))
	if part then
		return part
	end
	local demo = workspace:FindFirstChild("PaperWorkshop")
	local demoSpawns = demo and demo:FindFirstChild("Spawns")
	return demoSpawns and demoSpawns:FindFirstChild("Start") or nil
end

return Areas
