# Slop index — read before building anything

"Slop" = design and map patterns this project refuses to ship. Each topic file lists the anti-patterns for one area, with IDs (`G` = game/mechanics, `M` = map/visual).

**Rule:** before designing or building a mechanic, system, object, or map piece, find it in the routing table below and read **every** file listed for it. Then check the result against those entries. Only read what the table points to. Building a streetlamp doesn't need the boss or economy files.

If the thing isn't in the table, pick the closest rows, read their files, and add a row here.

## Routing table

| Building… | Read |
|---|---|
| **Any placed geometry at all** (always) | [map/geometry-quality](map/geometry-quality.md) |
| Streetlamp, bench, trash can, sign post, any street furniture | [map/props-set-dressing](map/props-set-dressing.md), [map/scale](map/scale.md), [map/lighting-effects](map/lighting-effects.md), [map/art-style-materials](map/art-style-materials.md) |
| Clutter, crates as decoration, debris, pipes, machinery, set dressing | [map/props-set-dressing](map/props-set-dressing.md), [map/scale](map/scale.md), [map/art-style-materials](map/art-style-materials.md) |
| Building, facade, wall, window, door, stairs, floors | [map/buildings-architecture](map/buildings-architecture.md), [map/scale](map/scale.md), [map/art-style-materials](map/art-style-materials.md) |
| Room interior, lab, office, furniture | [map/interiors-furniture](map/interiors-furniture.md), [map/buildings-architecture](map/buildings-architecture.md), [map/props-set-dressing](map/props-set-dressing.md), [map/scale](map/scale.md) |
| Roads, sidewalks, plazas, districts, city blocks | [map/roads-urban-layout](map/roads-urban-layout.md), [map/navigation-composition](map/navigation-composition.md), [map/scale](map/scale.md) |
| Terrain, ground, trees, grass, water, height changes | [map/terrain-vegetation-water](map/terrain-vegetation-water.md), [map/scale](map/scale.md) |
| Lights, fog, particles, glow, neon, skybox, atmosphere | [map/lighting-effects](map/lighting-effects.md), [map/art-style-materials](map/art-style-materials.md) |
| Colors, materials, textures, decals, art direction | [map/art-style-materials](map/art-style-materials.md) |
| Level section layout, routes, landmarks, backdrops, level edges | [map/navigation-composition](map/navigation-composition.md), [map/roads-urban-layout](map/roads-urban-layout.md), [game/world-structure](game/world-structure.md) |
| Tips, signs, arrows, labels, hint text, tutorials, waypoints | [game/player-guidance](game/player-guidance.md), [map/navigation-composition](map/navigation-composition.md), [map/art-style-materials](map/art-style-materials.md) |
| Puzzles (plates, levers, switches, sequences, co-op) | [game/player-guidance](game/player-guidance.md), [game/minigames](game/minigames.md) |
| Collectibles, score bubbles, secrets, hidden areas | [game/quests-narrative-collectibles](game/quests-narrative-collectibles.md), [map/navigation-composition](map/navigation-composition.md) |
| Score, costumes, unlocks, rewards, progression, saving | [game/progression-economy](game/progression-economy.md) |
| Player moves: jumps, lane shifting, swinging, ledge grab, any new ability | [game/movement-traversal](game/movement-traversal.md) |
| Hazards, enemies, bosses, combat, damage | [game/combat-enemies](game/combat-enemies.md) |
| Stealth, detection, guards | [game/stealth](game/stealth.md), [game/combat-enemies](game/combat-enemies.md) |
| Health, timers, meters, resources, inventory | [game/survival-resources](game/survival-resources.md), [game/progression-economy](game/progression-economy.md) |
| Story, dialogue, NPCs, quests, choices | [game/quests-narrative-collectibles](game/quests-narrative-collectibles.md) |
| Procedural generation, level variety, run structure, crafting | [game/world-structure](game/world-structure.md), [game/progression-economy](game/progression-economy.md) |
| Timing challenges, side activities | [game/minigames](game/minigames.md) |
