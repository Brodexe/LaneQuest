-- LevelClient: the local half of the shared level pieces.
--   movers ride smoothly under your own character, springs and stomps bounce you, critters you touch report it,
--   glue slows you, keepsakes you've found vanish (and appear on the hub shelf), their notes show on a card,
--   checkpoint markers raise their flag.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("PaperWorkshop")
local Config = require(Shared:WaitForChild("Config"))
local Motion = require(Shared:WaitForChild("Motion"))
local Remotes = Shared:WaitForChild("Remotes")

local char, hum, hrp
local function onCharacter(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	hrp = c:WaitForChild("HumanoidRootPart")
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local function tagList(tag)
	local list = {}
	local function refresh()
		table.clear(list)
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			if inst:IsDescendantOf(workspace) then
				table.insert(list, inst)
			end
		end
	end
	refresh()
	CollectionService:GetInstanceAddedSignal(tag):Connect(refresh)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(refresh)
	return list
end
local movers = tagList("Mover")
local critters = tagList("Critter")
local springs = tagList("Spring")
local glues = tagList("Glue")

local function pivotPos(inst)
	return inst:IsA("Model") and inst:GetPivot().Position or inst.Position
end

local function inside(part, pos, pad)
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2 + Vector3.new(pad or 0, pad or 0, pad or 0)
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

---------------------------------------------------------------- bounce
local function bounce(up, side)
	if not (hrp and hum) then
		return
	end
	local v = hrp.AssemblyLinearVelocity
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	hrp.AssemblyLinearVelocity = Vector3.new(side ~= 0 and side or v.X, up, 0)
end
Remotes:WaitForChild("Bounce").OnClientEvent:Connect(bounce)

---------------------------------------------------------------- movers (before physics, so we stand on where they really are)
RunService.PreSimulation:Connect(function()
	local t = Motion.now()
	local here = hrp and hrp.Position
	for _, m in ipairs(movers) do
		if not here or (pivotPos(m) - here).Magnitude < 260 then
			Motion.apply(m, t)
		end
	end
end)

---------------------------------------------------------------- critters, springs, glue (after physics)
local StompRemote = Remotes:WaitForChild("Stomp")
local HurtRemote = Remotes:WaitForChild("Hurt")
local lastHurt, lastStomp, lastSpring = 0, 0, 0
local inGlue = false

RunService.Heartbeat:Connect(function()
	if not (hrp and hrp.Parent and hum) or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	local pos = hrp.Position
	local vel = hrp.AssemblyLinearVelocity
	local feet = pos.Y - 3
	local ragdolled = hum:GetState() == Enum.HumanoidStateType.Physics

	for _, c in ipairs(critters) do
		local root = c.PrimaryPart
		if root and not ragdolled then
			local cpos = root.Position
			if math.abs(cpos.X - pos.X) < 12 and math.abs(cpos.Y - pos.Y) < 12 and math.abs(cpos.Z - pos.Z) < 3 then
				local size = c:GetAttribute("HitSize") or Vector3.new(3, 2, 2)
				local top = cpos.Y + size.Y / 2
				local overX = math.abs(cpos.X - pos.X) < size.X / 2 + 0.9
				local stunned = c:GetAttribute("Stunned")
				if overX and c:GetAttribute("Stompable") and not stunned and vel.Y < 1 and feet > top - 0.9 and feet < top + 1.4 and now - lastStomp > 0.35 then
					lastStomp = now
					StompRemote:FireServer(c)
					bounce(c:GetAttribute("StompBounce") or 38, 0)
				elseif overX and not stunned and not c:GetAttribute("Harmless") and feet < top - 0.6 and pos.Y + 2 > cpos.Y - size.Y / 2 and now - lastHurt > 1.5 then
					lastHurt = now
					HurtRemote:FireServer(c)
				end
			end
		end
	end

	-- springs: landing on top throws you up (Power = launch speed)
	if vel.Y < 2 and now - lastSpring > 0.3 then
		for _, s in ipairs(springs) do
			if s:GetAttribute("Armed") ~= false then
				local rel = s.CFrame:PointToObjectSpace(Vector3.new(pos.X, feet, s.Position.Z))
				if math.abs(rel.X) < s.Size.X / 2 + 0.3 and rel.Y > s.Size.Y / 2 - 0.4 and rel.Y < s.Size.Y / 2 + 0.9 and math.abs(pos.Z - s.Position.Z) < s.Size.Z / 2 + 0.5 then
					lastSpring = now
					bounce(s:GetAttribute("Power") or 52, 0)
					s:SetAttribute("Twang", now)
					break
				end
			end
		end
	end

	-- glue: thick going, no jumping
	local sticky = false
	for _, g in ipairs(glues) do
		if inside(g, Vector3.new(pos.X, feet + 0.3, pos.Z), 0.2) then
			sticky = true
			break
		end
	end
	if sticky ~= inGlue then
		inGlue = sticky
		hum.WalkSpeed = sticky and Config.WALK_SPEED * 0.38 or Config.WALK_SPEED
		hum.JumpHeight = sticky and 0.6 or Config.JUMP_HEIGHT
	end
end)

---------------------------------------------------------------- keepsakes: hide the ones you have, show them on the hub shelf
local function hasKeep(id)
	return player:GetAttribute("Flag_Keep_" .. tostring(id)) == true
end
local function setLocalVisible(inst, visible)
	local parts = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = visible and 0 or 1
		elseif p:IsA("Light") then
			p.Enabled = visible
		elseif p:IsA("SurfaceGui") or p:IsA("BillboardGui") then
			p.Enabled = visible
		end
	end
end
local function refreshKeepsakes()
	for _, k in ipairs(CollectionService:GetTagged("Keepsake")) do
		setLocalVisible(k, not hasKeep(k:GetAttribute("Id")))
	end
	for _, d in ipairs(CollectionService:GetTagged("KeepsakeDisplay")) do
		setLocalVisible(d, hasKeep(d:GetAttribute("Id")))
	end
end
player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 10) == "Flag_Keep_" then
		refreshKeepsakes()
	end
end)
task.defer(refreshKeepsakes)

-- the note card: a scrap of paper that slides up, stays a while, and goes
local noteGui = Instance.new("ScreenGui")
noteGui.Name = "KeepsakeNote"
noteGui.ResetOnSpawn = false
noteGui.DisplayOrder = 20
noteGui.Parent = player:WaitForChild("PlayerGui")
local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 1, 10)
card.Size = UDim2.fromOffset(360, 150)
card.Rotation = 1.2
card.BackgroundColor3 = Color3.fromRGB(240, 230, 206)
card.BorderSizePixel = 0
card.Parent = noteGui
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 4)
cc.Parent = card
local cs = Instance.new("UIStroke")
cs.Color = Color3.fromRGB(146, 108, 70)
cs.Thickness = 2
cs.Parent = card
local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(16, 8)
titleLabel.Size = UDim2.new(1, -32, 0, 30)
titleLabel.FontFace = Font.fromEnum(Enum.Font.PatrickHand)
titleLabel.TextSize = 26
titleLabel.TextColor3 = Color3.fromRGB(132, 44, 38)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = card
local noteLabel = Instance.new("TextLabel")
noteLabel.BackgroundTransparency = 1
noteLabel.Position = UDim2.fromOffset(16, 40)
noteLabel.Size = UDim2.new(1, -32, 1, -50)
noteLabel.FontFace = Font.fromEnum(Enum.Font.PatrickHand)
noteLabel.TextSize = 21
noteLabel.TextColor3 = Color3.fromRGB(62, 50, 42)
noteLabel.TextWrapped = true
noteLabel.TextXAlignment = Enum.TextXAlignment.Left
noteLabel.TextYAlignment = Enum.TextYAlignment.Top
noteLabel.Parent = card
local noteToken = 0
Remotes:WaitForChild("KeepsakeNote").OnClientEvent:Connect(function(_, title, note)
	noteToken += 1
	local token = noteToken
	titleLabel.Text = title or ""
	noteLabel.Text = note or ""
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -170) }):Play()
	task.delay(math.clamp(4 + #(note or "") * 0.04, 5, 10), function()
		if token == noteToken then
			TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1, 10) }):Play()
		end
	end)
end)

---------------------------------------------------------------- checkpoint markers: the flag goes up once anyone reaches it
local function watchMarker(m)
	local function raise(instant)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and typeof(p:GetAttribute("UpCF")) == "CFrame" then
				if instant then
					p.CFrame = p:GetAttribute("UpCF")
				else
					TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = p:GetAttribute("UpCF") }):Play()
				end
			elseif p:IsA("Light") then
				p.Enabled = true
			end
		end
	end
	if m:GetAttribute("Lit") then
		raise(true)
	end
	m:GetAttributeChangedSignal("Lit"):Connect(function()
		if m:GetAttribute("Lit") then
			raise(false)
		end
	end)
end
for _, m in ipairs(CollectionService:GetTagged("CheckpointMarker")) do
	watchMarker(m)
end
CollectionService:GetInstanceAddedSignal("CheckpointMarker"):Connect(watchMarker)
