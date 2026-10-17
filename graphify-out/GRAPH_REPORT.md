# Graph Report - LBP_clone_game  (2026-10-17)

## Corpus Check
- 43 files · ~28,417 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: (none) 3)

## Summary
- 264 nodes · 456 edges · 16 communities (11 shown, 5 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 45 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Hub.server.luau
- PlatformerClient.client.luau
- Travel.luau
- LevelKit.luau
- Beetle.server.luau
- local_fingerprint.py
- GameServer.server.luau
- README.md
- PaperClient.client.luau
- WorkshopServer.server.luau
- PlatformerHUD.client.luau
- Mechanisms.server.luau

## God Nodes (most connected - your core abstractions)
1. `Kit:part()` - 14 edges
2. `Config.laneZ()` - 12 edges
3. `Util.tweenValue()` - 10 edges
4. `Kit:decor()` - 10 edges
5. `lowerBridge()` - 9 edges
6. `onArrive()` - 9 edges
7. `Util.playAt()` - 9 edges
8. `setHint()` - 8 edges
9. `tryShift()` - 8 edges
10. `ending()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `laneZ()` --calls--> `Config.laneZ()`  [INFERRED]
  roblox_src/ServerStorage/_Archive_ResearchFacility/PlatformerClient.client.luau → roblox_src/ServerStorage/_Archive_ResearchFacility/PlatformerShared/Config.luau
- `tryShift()` --calls--> `Config.laneZ()`  [INFERRED]
  roblox_src/ServerStorage/_Archive_ResearchFacility/PlatformerClient.client.luau → roblox_src/ServerStorage/_Archive_ResearchFacility/PlatformerShared/Config.luau
- `applyAudio()` --calls--> `Areas.get()`  [INFERRED]
  roblox_src/StarterPlayer/StarterPlayerScripts/TravelClient.client.luau → roblox_src/ReplicatedStorage/PaperWorkshop/Areas.luau
- `applyLighting()` --calls--> `Areas.get()`  [INFERRED]
  roblox_src/StarterPlayer/StarterPlayerScripts/TravelClient.client.luau → roblox_src/ReplicatedStorage/PaperWorkshop/Areas.luau
- `place()` --calls--> `Areas.spawnPart()`  [INFERRED]
  roblox_src/ServerScriptService/PaperWorkshop/Travel.luau → roblox_src/ReplicatedStorage/PaperWorkshop/Areas.luau

## Import Cycles
- None detected.

## Communities (16 total, 5 thin omitted)

### Community 1 - "Hub.server.luau"
Cohesion: 0.12
Nodes (27): ending(), faceX(), hopTo(), lowerBridge(), onArrive(), placePK(), say(), open() (+19 more)

### Community 2 - "PlatformerClient.client.luau"
Cohesion: 0.15
Nodes (28): climbLedge(), contextHint(), doDown(), doGrab(), doJump(), doUp(), dropLedge(), endSwing() (+20 more)

### Community 3 - "Travel.luau"
Cohesion: 0.16
Nodes (11): Areas.get(), Areas.spawnPart(), onPlayer(), place(), ragdolled(), Travel.area(), Travel.go(), applyAudio() (+3 more)

### Community 4 - "LevelKit.luau"
Cohesion: 0.16
Nodes (29): attrs(), Kit:block(), Kit:bubble(), Kit:bubbleArc(), Kit:bubbleRow(), Kit:checkpoint(), Kit:_collectible(), Kit:crate() (+21 more)

### Community 5 - "Beetle.server.luau"
Cohesion: 0.36
Nodes (5): hardReset(), onTouched(), playAt(), setState(), stagger()

### Community 6 - "local_fingerprint.py"
Cohesion: 0.39
Nodes (3): fingerprint(), local(), main()

### Community 7 - "GameServer.server.luau"
Cohesion: 0.20
Nodes (15): applyCostume(), costumeById(), countSecrets(), defaultProfile(), finishLevel(), isUnlocked(), newRun(), onCharacter() (+7 more)

### Community 8 - "README.md"
Cohesion: 0.04
Nodes (24): graphify, LaneQuest: how changes travel, Slop check (before building anything), Game slop: combat and enemies, Game slop: minigames and skill checks, Game slop: movement and traversal, Game slop: player guidance, Game slop: progression and economy (+16 more)

### Community 9 - "PaperClient.client.luau"
Cohesion: 0.21
Nodes (11): isR15(), nearestGrabbable(), raise(), release(), selfDestruct(), setHoldPose(), slap(), swingArm() (+3 more)

### Community 10 - "WorkshopServer.server.luau"
Cohesion: 0.21
Nodes (10): celebrate(), onPlayer(), paperBurst(), playAt(), playMusicBox(), releaseHeld(), respawn(), setRagdoll() (+2 more)

### Community 11 - "PlatformerHUD.client.luau"
Cohesion: 0.24
Nodes (7): button(), corner(), label(), rebuildMenu(), reqText(), stroke(), tbtn()

## Knowledge Gaps
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Config.laneZ()` connect `LevelKit.luau` to `PlatformerClient.client.luau`?**
  _High betweenness centrality (0.116) - this node is a cross-community bridge._
- **Are the 11 inferred relationships involving `Config.laneZ()` (e.g. with `Kit:checkpoint()` and `Kit:_collectible()`) actually correct?**
  _`Config.laneZ()` has 11 INFERRED edges - model-reasoned connections that need verification._
- **Should `Hub.server.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.11711711711711711 - nodes in this community are weakly interconnected._
- **Why does `Travel.cue()` connect `Hub.server.luau` to `Travel.luau`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `Util.tweenValue()` (e.g. with `ending()` and `hopTo()`) actually correct?**
  _`Util.tweenValue()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Should `PlatformerClient.client.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.14623655913978495 - nodes in this community are weakly interconnected._
- **Are the 4 inferred relationships involving `lowerBridge()` (e.g. with `Travel.cue()` and `Util.playAt()`) actually correct?**
  _`lowerBridge()` has 4 INFERRED edges - model-reasoned connections that need verification._