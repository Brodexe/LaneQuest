-- Travel: moving players between the Demo, the Loomworks hub and the Drowned Archive.
-- Owns each player's area, checkpoint and story flags (session only), places characters on (re)spawn,
-- and runs the paper-curtain transition. Required by the area scripts; initialises once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("PaperWorkshop")
local Areas = require(Shared:WaitForChild("Areas"))
local Remotes = Shared:WaitForChild("Remotes")
local ForceRelease = script.Parent:WaitForChild("ForceRelease")

local Transition = Remotes:FindFirstChild("Transition") or Instance.new("RemoteEvent")
Transition.Name = "Transition"
Transition.Parent = Remotes
local CameraCue = Remotes:FindFirstChild("CameraCue") or Instance.new("RemoteEvent")
CameraCue.Name = "CameraCue"
CameraCue.Parent = Remotes

local Travel = {}
local busy = {}

function Travel.flag(player, name)
	return player:GetAttribute("Flag_" .. name) == true
end

function Travel.setFlag(player, name)
	player:SetAttribute("Flag_" .. name, true)
end

function Travel.area(player)
	return player:GetAttribute("Area") or "Demo"
end

function Travel.setCheckpoint(player, spawnName)
	player:SetAttribute("Checkpoint", spawnName)
end

function Travel.isTravelling(player)
	return busy[player] == true
end

-- brief camera emphasis on the client (the player keeps control)
function Travel.cue(player, focus, distance, duration)
	CameraCue:FireClient(player, focus, distance, duration)
end

local function ragdolled(char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BallSocketConstraint") and d.Enabled then
			return true
		end
	end
	return false
end

local function place(player, char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local part = Areas.spawnPart(Travel.area(player), player:GetAttribute("Checkpoint"))
	if not (hrp and part) then
		return
	end
	char:PivotTo(part.CFrame * CFrame.new(0, 3.3, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

-- move a player to another area/spawn behind the paper curtain
function Travel.go(player, areaName, spawnName)
	if busy[player] or not Areas.List[areaName] then
		return false
	end
	busy[player] = true
	ForceRelease:Fire(player)
	Transition:FireClient(player, "close", areaName)
	task.wait(0.6)
	player:SetAttribute("Area", areaName)
	player:SetAttribute("Checkpoint", spawnName)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if char and hum and hum.Health > 0 and not ragdolled(char) then
		place(player, char)
	else
		player:LoadCharacter() -- placement happens in CharacterAdded
	end
	task.wait(0.3)
	Transition:FireClient(player, "open", areaName)
	busy[player] = nil
	return true
end

local function onPlayer(player)
	if not player:GetAttribute("Area") then
		player:SetAttribute("Area", "Demo")
		player:SetAttribute("Checkpoint", "Start")
	end
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 5)
		place(player, char)
	end)
	if player.Character then
		task.spawn(place, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

return Travel
