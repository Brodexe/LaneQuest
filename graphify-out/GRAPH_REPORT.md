# Graph Report - LBP_copy  (2026-10-18)

## Corpus Check
- 48 files · ~38,596 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 5 file(s) not represented in the graph (top: (none) 4, .claude 1)

## Summary
- 362 nodes · 668 edges · 20 communities (15 shown, 5 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 56 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1b10f75a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- BuildKit.luau
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
- Critters.server.luau
- Motion.luau
- LevelClient.client.luau

## God Nodes (most connected - your core abstractions)
1. `Util.playAt()` - 17 edges
2. `Kit:part()` - 14 edges
3. `Config.laneZ()` - 12 edges
4. `K.model()` - 11 edges
5. `K.box()` - 11 edges
6. `Util.tweenValue()` - 10 edges
7. `Kit:decor()` - 10 edges
8. `lowerBridge()` - 9 edges
9. `onArrive()` - 9 edges
10. `K.book()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `sendBack()` --calls--> `Travel.isTravelling()`  [INFERRED]
  roblox_src/ServerScriptService/PaperWorkshop/LevelRuntime.server.luau → roblox_src/ServerScriptService/PaperWorkshop/Travel.luau
- `mouseFlip()` --calls--> `Util.playAt()`  [INFERRED]
  roblox_src/ServerScriptService/PaperWorkshop/Critters.server.luau → roblox_src/ServerScriptService/PaperWorkshop/Util.luau
- `mouseRecover()` --calls--> `Util.playAt()`  [INFERRED]
  roblox_src/ServerScriptService/PaperWorkshop/Critters.server.luau → roblox_src/ServerScriptService/PaperWorkshop/Util.luau
- `species.JackInTheBox.step()` --calls--> `Util.playAt()`  [INFERRED]
  roblox_src/ServerScriptService/PaperWorkshop/Critters.server.luau → roblox_src/ServerScriptService/PaperWorkshop/Util.luau
- `lightMarker()` --calls--> `Util.playAt()`  [INFERRED]
  roblox_src/ServerScriptService/PaperWorkshop/LevelRuntime.server.luau → roblox_src/ServerScriptService/PaperWorkshop/Util.luau

## Import Cycles
- None detected.

## Communities (20 total, 5 thin omitted)

### Community 0 - "BuildKit.luau"
Cohesion: 0.12
Nodes (40): K.attrs(), K.ball(), K.book(), K.bookRow(), K.box(), K.button(), K.chance(), K.checkpoint() (+32 more)

### Community 1 - "Hub.server.luau"
Cohesion: 0.08
Nodes (36): ending(), faceX(), hopTo(), lowerBridge(), onArrive(), placePK(), say(), open() (+28 more)

### Community 2 - "PlatformerClient.client.luau"
Cohesion: 0.15
Nodes (28): climbLedge(), contextHint(), doDown(), doGrab(), doJump(), doUp(), dropLedge(), endSwing() (+20 more)

### Community 3 - "Travel.luau"
Cohesion: 0.13
Nodes (14): Areas.get(), Areas.spawnPart(), cpKey(), watchPlayer(), onPlayer(), place(), ragdolled(), Travel.area() (+6 more)

### Community 4 - "LevelKit.luau"
Cohesion: 0.16
Nodes (29): attrs(), Kit:block(), Kit:bubble(), Kit:bubbleArc(), Kit:bubbleRow(), Kit:checkpoint(), Kit:_collectible(), Kit:crate() (+21 more)

### Community 5 - "Beetle.server.luau"
Cohesion: 0.39
Nodes (6): caught(), hardReset(), onTouched(), playAt(), setState(), stagger()

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
Cohesion: 0.19
Nodes (16): watchMarker(), ignoreList(), isR15(), layerOpen(), nearestGrabbable(), raise(), release(), selfDestruct() (+8 more)

### Community 10 - "WorkshopServer.server.luau"
Cohesion: 0.21
Nodes (10): celebrate(), onPlayer(), paperBurst(), playAt(), playMusicBox(), releaseHeld(), respawn(), setRagdoll() (+2 more)

### Community 11 - "PlatformerHUD.client.luau"
Cohesion: 0.24
Nodes (7): button(), corner(), label(), rebuildMenu(), reqText(), stroke(), tbtn()

### Community 16 - "Critters.server.luau"
Cohesion: 0.22
Nodes (11): hrpOf(), laneZ(), mouseFlip(), mouseRecover(), onLid(), rig(), species.JackInTheBox.step(), species.WindupMouse.init() (+3 more)

### Community 17 - "Motion.luau"
Cohesion: 0.38
Nodes (9): clock(), Motion.apply(), Motion.pose(), Motion.setRunning(), Motion.setState(), Motion.toggleK(), now(), smooth() (+1 more)

### Community 18 - "LevelClient.client.luau"
Cohesion: 0.28
Nodes (3): hasKeep(), refreshKeepsakes(), setLocalVisible()

## Knowledge Gaps
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Config.laneZ()` connect `LevelKit.luau` to `PlatformerClient.client.luau`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **Are the 16 inferred relationships involving `Util.playAt()` (e.g. with `ending()` and `lowerBridge()`) actually correct?**
  _`Util.playAt()` has 16 INFERRED edges - model-reasoned connections that need verification._
- **Should `BuildKit.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.11616161616161616 - nodes in this community are weakly interconnected._
- **Why does `Util.playAt()` connect `Hub.server.luau` to `Critters.server.luau`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Are the 11 inferred relationships involving `Config.laneZ()` (e.g. with `Kit:checkpoint()` and `Kit:_collectible()`) actually correct?**
  _`Config.laneZ()` has 11 INFERRED edges - model-reasoned connections that need verification._
- **Should `Hub.server.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.08489795918367347 - nodes in this community are weakly interconnected._
- **Why does `tryShift()` connect `PlatformerClient.client.luau` to `LevelKit.luau`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._