-- Archive: the Drowned Archive. Deep water, checkpoints, the Pagekeeper, the counterweight bridge,
-- the catalog card, the Forgotten Book's fragment and the lift home.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Travel = require(script.Parent:WaitForChild("Travel"))
local Util = require(script.Parent:WaitForChild("Util"))
local Slapped = script.Parent:WaitForChild("Slapped")

local arc = workspace:WaitForChild("DrownedArchive")
local mech = arc:WaitForChild("Mechanisms")
local triggers = arc:WaitForChild("Triggers")
local pk = arc:WaitForChild("Characters"):WaitForChild("Pagekeeper")
local head = pk:WaitForChild("Head")
local book = mech:WaitForChild("ForgottenBook")
local cover = book:WaitForChild("Cover")
local spread = book:WaitForChild("PageSpread")
local writing = spread:WaitForChild("Writing"):WaitForChild("Text")
local cardGui = book:WaitForChild("Glow"):WaitForChild("FragmentCard")
local cardText = cardGui:WaitForChild("Card"):WaitForChild("Text")
local cardFrame = cardGui.Card
local glow = book:WaitForChild("Glow"):FindFirstChildOfClass("PointLight")
local heavy = mech:WaitForChild("HeavyBook")
local basket = mech:WaitForChild("Basket")
local rope = mech:WaitForChild("BasketRope")
local bridge = mech:WaitForChild("Drawbridge")
local crooked = mech:WaitForChild("CrookedStack")
local gapMark = mech:WaitForChild("GapMark")
local lift = mech:WaitForChild("LiftDrawer")

local state = { bridge = false, pkAt = "room", busy = false, liftOut = false, ending = false }

---------------------------------------------------------------- the Pagekeeper: movement and facing
-- eyes on both faces, so it reads from the side whichever way it turns
for _, e in ipairs(pk:GetChildren()) do
	if e.Name == "Eye" then
		local twin = e:Clone()
		local rel = pk.PrimaryPart.CFrame:PointToObjectSpace(e.Position)
		twin.Position = pk.PrimaryPart.CFrame:PointToWorldSpace(Vector3.new(rel.X, rel.Y, -rel.Z))
		twin.Parent = pk
	end
end
local carrying = false
local bookOffset = CFrame.new(0, 5.8, 0) * CFrame.Angles(math.rad(10), 0, 0)
local function placePK(cf)
	pk:PivotTo(cf)
	if carrying then
		book:PivotTo(cf * bookOffset)
	end
end
local function faceX(dir)
	local p = pk:GetPivot().Position
	placePK(CFrame.new(p) * (dir >= 0 and CFrame.identity or CFrame.Angles(0, math.pi, 0)))
end
-- hop from here to there in little bounces
local function hopTo(target, speed)
	local from = pk:GetPivot()
	local dist = (target - from.Position).Magnitude
	if dist < 0.05 then
		return
	end
	local dir = (target - from.Position).X >= 0 and 1 or -1
	local rot = dir >= 0 and CFrame.identity or CFrame.Angles(0, math.pi, 0)
	local t = dist / (speed or 6)
	local hops = math.max(1, math.floor(dist / 1.6))
	local done = false
	Util.tweenValue(0, 1, TweenInfo.new(t, Enum.EasingStyle.Linear), function(a)
		local p = from.Position:Lerp(target, a) + Vector3.new(0, math.abs(math.sin(a * hops * math.pi)) * 0.7, 0)
		placePK(CFrame.new(p) * rot)
		if a >= 1 then
			done = true
		end
	end)
	task.wait(t + 0.05)
end
local function say(lines)
	Util.say(head, lines, { offset = Vector3.new(0, 4.6, 0) })
end

---------------------------------------------------------------- idle: the stack slides, the Pagekeeper puts it right
task.spawn(function()
	local upright = crooked:GetPivot()
	local tilted = upright * CFrame.Angles(0, 0, math.rad(13))
	while true do
		task.wait(4.5 + math.random() * 2)
		if state.pkAt == "room" and not state.busy then
			Util.tweenModel(crooked, upright, tilted, TweenInfo.new(1.6, Enum.EasingStyle.Sine))
			task.wait(1.8)
			if state.pkAt == "room" and not state.busy then
				local p = pk:GetPivot().Position
				placePK(CFrame.new(p + Vector3.new(0, 0.5, 0)))
				task.wait(0.12)
				placePK(CFrame.new(p))
				Util.tweenModel(crooked, tilted, upright, TweenInfo.new(0.25, Enum.EasingStyle.Back))
				Util.playAt(crooked:GetPivot().Position, "PaperRustle", 0.2, 1.4)
			end
		end
	end
end)

---------------------------------------------------------------- arrival, checkpoints, deep water, proximity talk
local drowning = {}
local function onArrive(player)
	if not Travel.flag(player, "ArchiveVisited") then
		Travel.setFlag(player, "ArchiveVisited")
		task.wait(0.9)
		Travel.cue(player, Vector3.new(780, 22, -22), 96, 4.6)
	end
end
local function watchPlayer(player)
	player:GetAttributeChangedSignal("Area"):Connect(function()
		if player:GetAttribute("Area") == "Archive" then
			task.spawn(onArrive, player)
		end
	end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end

local function hrpOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

task.spawn(function()
	local deeps = CollectionService:GetTagged("DeepWater")
	while true do
		task.wait(0.15)
		for _, p in ipairs(Players:GetPlayers()) do
			local hrp = hrpOf(p)
			if hrp and p:GetAttribute("Area") == "Archive" then
				local pos = hrp.Position
				-- fished out of deep water at the last checkpoint
				if not drowning[p] then
					for _, d in ipairs(deeps) do
						if Util.isInside(d, pos) then
							drowning[p] = true
							Util.playAt(pos, "Splash", 0.8)
							task.delay(0.7, function()
								drowning[p] = nil
								if p.Parent then
									p:LoadCharacter()
								end
							end)
							break
						end
					end
				end
				if Util.isInside(triggers.CP_ReadingRoom, pos) and p:GetAttribute("Checkpoint") == "Entry" then
					Travel.setCheckpoint(p, "ReadingRoom")
				end
				if Util.isInside(triggers.CP_Tower, pos) and p:GetAttribute("Checkpoint") ~= "Tower" then
					Travel.setCheckpoint(p, "Tower")
					if state.pkAt == "tower" and not Travel.flag(p, "TowerTalk") then
						Travel.setFlag(p, "TowerTalk")
						if Travel.flag(p, "ArchiveComplete") then
							say({ "It hasn't written anything else.", "I check every day. Probably." })
						else
							say({
								Travel.flag(p, "ArchiveSecret") and "You found the dry place. Did the card still have its words?" or "Those shelves all had names. I'm sure of it. I can't remember a single one.",
								"The empty drawer up there... it's the same shape as the mark on the book. Was it always?",
							})
						end
					end
				end
				-- the catalog card in the cubby
				if Util.isInside(triggers.CardRead, pos) and not Travel.flag(p, "ArchiveSecret") then
					Travel.setFlag(p, "ArchiveSecret")
					Util.playAt(pos, "PageTurn", 0.5)
				end
				-- meeting the Pagekeeper in the reading room
				local pkPos = pk:GetPivot().Position
				if state.pkAt == "room" and not state.busy and (pos - pkPos).Magnitude < 12 then
					if not Travel.flag(p, "PagekeeperMet") then
						Travel.setFlag(p, "PagekeeperMet")
						faceX(pos.X - pkPos.X)
						say({ "...No. Stay.", "Oh! You're dry. Nobody's dry anymore.", "Are you a reader? You look a little like a bookmark." })
					elseif Travel.flag(p, "ArchiveComplete") and not Travel.flag(p, "RoomRevisit") then
						Travel.setFlag(p, "RoomRevisit")
						say("You came back! I straightened everything. It slid again.")
					end
				end
				if state.pkAt == "room" and not Travel.flag(p, "BookWarned") and Travel.flag(p, "PagekeeperMet") and (pos - cover.Position).Magnitude < 5 then
					Travel.setFlag(p, "BookWarned")
					say({ "Careful with that one.", "Every time it opens, there's less of it. I keep it shut now. Mostly." })
				end
			end
		end
		if heavy:GetAttribute("HeldBy") and not state.heavyJoke then
			state.heavyJoke = true
			say("That one's heavy. It's mostly water now.")
		end
	end
end)

---------------------------------------------------------------- the counterweight: the heavy book in the basket drops the bridge
local function lowerBridge(byPlayer)
	state.bridge = true
	arc:SetAttribute("BridgeLowered", true)
	CollectionService:RemoveTag(heavy, "Grabbable")
	Util.playAt(basket:GetPivot().Position, "Ratchet", 0.7, 0.8)
	local from = basket:GetPivot()
	local drop = 1.95
	Util.tweenValue(0, 1, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), function(a)
		basket:PivotTo(from - Vector3.new(0, drop * a, 0))
		local bottomOfRope = 9.4 - drop * a
		rope.Size = Vector3.new(0.06, 21.6 - bottomOfRope, 0.06)
		rope.CFrame = CFrame.new(792.2, (21.6 + bottomOfRope) / 2, 0)
	end)
	task.wait(0.4)
	if byPlayer then
		Travel.cue(byPlayer, Vector3.new(796, 7, 0), 40, 3)
	end
	Util.playAt(Vector3.new(801.7, 9, 0), "WoodCreak", 0.8, 0.8)
	Util.swingModel(bridge, CFrame.new(801.7, 2.9, 0), "Z", 0, 90, TweenInfo.new(1.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out))
	task.wait(1)
	Util.playAt(Vector3.new(796, 3, 0), "Splash", 0.9, 0.8)
	Util.playAt(Vector3.new(796, 3, 0), "Wood", 0.7, 0.7)
	task.wait(0.4)
	heavy.Anchored = true
	-- the Pagekeeper takes the book along
	state.busy = true
	faceX(1)
	say({ "You moved the weight! Nothing has moved in here in ages. Except the water.", "Wait. I'm bringing the book." })
	task.wait(4.2)
	hopTo(Vector3.new(767, 1.4, -1.7), 5)
	carrying = true
	Util.playAt(cover.Position, "PageTurn", 0.4)
	placePK(pk:GetPivot())
	task.wait(0.4)
	hopTo(Vector3.new(778, 1.4, -1.7), 6)
	hopTo(Vector3.new(784, 8.6, -1.7), 6)
	hopTo(Vector3.new(796, 3.2, -1.7), 7)
	hopTo(Vector3.new(805, 4, -1.7), 7)
	hopTo(Vector3.new(806, 4, -8), 5)
	hopTo(Vector3.new(812, 8, -8), 6)
	-- out of sight behind the hanging pages, it scurries on to the tower
	hopTo(Vector3.new(834, 8, -8), 9)
	hopTo(Vector3.new(841.5, 8, -1.7), 6)
	carrying = false
	book:PivotTo(book:GetAttribute("TowerCF"))
	Util.playAt(cover.Position, "Wood", 0.4, 1.3)
	faceX(-1)
	state.pkAt = "tower"
	state.busy = false
end

task.spawn(function()
	local vol = triggers:WaitForChild("BasketVolume")
	while not state.bridge do
		task.wait(0.2)
		if Util.isInside(vol, heavy.Position) and not heavy:GetAttribute("HeldBy") then
			local _, near = nil, nil
			local who = Util.nearestPlayer(heavy.Position, 30)
			lowerBridge(who)
		end
	end
end)

---------------------------------------------------------------- the ending: the book writes a few words for you, then forgets them
local FRAGMENT = "This book remembers what the Loom forgot.\nIf you can read this, a thread has found you.\nDo not let it finish the"
local threadLine
local function ending(player)
	state.ending = true
	local first = not Travel.flag(player, "ArchiveComplete")
	Util.playAt(cover.Position, "GlassTink", 0.45, 0.8)
	TweenService:Create(glow, TweenInfo.new(1), { Brightness = 1.6 }):Play()
	-- a thin thread reaches from the mark to the gap in the tower
	local a = cover.Position + cover.CFrame.UpVector * 0.15
	local b = gapMark:GetPivot().Position
	threadLine = Instance.new("Part")
	threadLine.Name = "ConnectionThread"
	threadLine.Anchored, threadLine.CanCollide, threadLine.CanQuery, threadLine.CanTouch, threadLine.CastShadow = true, false, false, false, false
	threadLine.Material = Enum.Material.Fabric
	threadLine.Color = Color3.fromRGB(222, 156, 64)
	threadLine.Parent = mech
	Util.tweenValue(0, 1, TweenInfo.new(1.4, Enum.EasingStyle.Quad), function(k)
		local e = a:Lerp(b, k)
		threadLine.Size = Vector3.new(0.06, 0.06, math.max(0.05, (e - a).Magnitude))
		threadLine.CFrame = CFrame.lookAt((a + e) / 2, b)
	end)
	task.wait(1.4)
	for _, p in ipairs(gapMark:GetDescendants()) do
		if p:IsA("BasePart") then
			TweenService:Create(p, TweenInfo.new(0.8), { Color = Color3.fromRGB(240, 196, 120) }):Play()
		end
	end
	Util.playAt(b, "GlassTink", 0.35, 1.2)
	-- the cover lifts away and words appear
	local hinge = cover.CFrame * CFrame.new(-1.7, 0, 0)
	local closedCF = cover.CFrame
	Util.tweenValue(0, 1, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), function(k)
		cover.CFrame = hinge * CFrame.Angles(0, 0, math.rad(165 * k)) * hinge:ToObjectSpace(closedCF)
	end)
	Util.playAt(cover.Position, "PageTurn", 0.6)
	task.wait(0.9)
	spread.Transparency = 0
	writing.TextTransparency = 0
	writing.Text = ""
	cardText.Text = ""
	cardFrame.BackgroundTransparency = 1
	cardGui.Enabled = true
	TweenService:Create(cardFrame, TweenInfo.new(0.6), { BackgroundTransparency = 0.08 }):Play()
	local speed = first and 0.05 or 0.03
	for i = 1, #FRAGMENT do
		writing.Text = string.sub(FRAGMENT, 1, i)
		cardText.Text = writing.Text
		task.wait(speed)
	end
	task.wait(first and 2.6 or 1.6)
	-- and then it forgets, letter by letter, quietly
	Util.playAt(cover.Position, "GlassTink", 0.2, 0.6)
	for i = #FRAGMENT, 0, -1 do
		writing.Text = string.sub(FRAGMENT, 1, i)
		cardText.Text = writing.Text
		task.wait(0.012)
	end
	TweenService:Create(cardFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.wait(0.6)
	cardGui.Enabled = false
	spread.Transparency = 1
	Util.tweenValue(1, 0, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), function(k)
		cover.CFrame = hinge * CFrame.Angles(0, 0, math.rad(165 * k)) * hinge:ToObjectSpace(closedCF)
	end)
	TweenService:Create(glow, TweenInfo.new(1.5), { Brightness = 0 }):Play()
	TweenService:Create(threadLine, TweenInfo.new(2), { Transparency = 1 }):Play()
	task.wait(1)
	if first then
		Travel.setFlag(player, "ArchiveComplete")
		say({ "It wrote something. It hasn't written anything in... I don't know how long.", "...It wrote it for you." })
	else
		say("Again? ...It's still in there. Somewhere.")
	end
	-- the tower's bottom drawer slides out, for the first time since the water came
	if not state.liftOut then
		task.wait(first and 5 or 1)
		state.liftOut = true
		Util.playAt(lift:GetPivot().Position, "WoodCreak", 0.7, 0.9)
		local from = lift:GetPivot()
		Util.tweenModel(lift, from, from + Vector3.new(0, 0, 9.6), TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		task.wait(1.7)
		if first then
			say("That drawer hasn't moved since the water came.")
		end
	end
	threadLine:Destroy()
	state.ending = false
end

Slapped.Event:Connect(function(part, player)
	if part == cover and state.pkAt == "tower" and not state.ending and not state.busy then
		task.spawn(ending, player)
	end
end)

---------------------------------------------------------------- the lift: step into the drawer and it carries you up and out
task.spawn(function()
	local lowered = lift:GetPivot()
	local riding = false
	while true do
		task.wait(0.2)
		if state.liftOut and not riding then
			local floor = lift.PrimaryPart
			for _, p in ipairs(Players:GetPlayers()) do
				local hrp = hrpOf(p)
				if hrp and not Travel.isTravelling(p) then
					local rel = floor.CFrame:PointToObjectSpace(hrp.Position)
					if math.abs(rel.X) < floor.Size.X / 2 and math.abs(rel.Z) < floor.Size.Z / 2 + 0.6 and rel.Y > 0 and rel.Y < 6 then
						riding = true
						if not Travel.flag(p, "Farewell") then
							Travel.setFlag(p, "Farewell")
							say("If you find where its words went... tell it I kept the cover dry.")
						end
						task.wait(0.8)
						Util.playAt(floor.Position, "Ratchet", 0.6, 0.7)
						local start = lift:GetPivot()
						Util.tweenModel(lift, start, start + Vector3.new(0, 11, 0), TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
						task.wait(1.2)
						Travel.go(p, "Hub", "FromArchive")
						task.wait(2.5)
						lift:PivotTo(start)
						riding = false
						break
					end
				end
			end
		end
	end
end)
