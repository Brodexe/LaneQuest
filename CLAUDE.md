## LaneQuest: how changes travel

The game lives in Roblox Studio (place "LBP Clone", reached through the `Roblox_Studio` MCP server). `roblox_src/` is a mirror of its scripts that graphify indexes, kept in the LaneQuest GitHub repo. Two people work on it asynchronously: whoever changes Studio syncs the mirror and pushes; everyone else pulls. Never read the whole place to find out what changed — git already says.

**First time on a machine (after cloning):** run `graphify hook install` once. It adds the git hooks and the `graph.json` merge driver, which live in local git config and don't come with the clone.

**Start of every session, always:** run `git pull` before doing anything else. If it brought in changes, run `graphify update .` and tell the user which files changed (`git diff --stat ORIG_HEAD HEAD`). Don't touch Studio for this.

**Always push your changes.** Whenever you finish a piece of work that changed anything (scripts in Studio, or any file in this repo: docs, slop entries, tools), sync if Studio scripts changed (steps below), then `git pull`, commit, and `git push` before ending your turn. Never leave changes unpushed. The user's own Studio edits get synced and pushed when they ask.

**Syncing Studio scripts into the mirror** (when you changed scripts in Studio, or the user asks to sync/push their Studio changes):
1. Run the code in `tools/studio_fingerprint.luau` with `execute_luau` (datamodel `Edit`), save the returned JSON to a temp file, then run `python -I tools/local_fingerprint.py --diff <temp file>`. (On Brody's machine the `python` on PATH is the Microsoft Store stub; use `C:/Users/cates/AppData/Roaming/uv/tools/serena-agent/Scripts/python.exe`.)
2. For each changed/added script, copy its exact `Source` into `roblox_src/` (mirror path = Studio path; `.server.luau` for Script, `.client.luau` for LocalScript, `.luau` for ModuleScript); delete files for removed scripts. If a "removed" and an "added" path share a fingerprint, it was moved: move the file instead of re-reading it.
3. Run `local_fingerprint.py --save`, then `--diff` again and confirm IN SYNC.
4. Run `graphify update .`, commit, and push.

Pull before you start editing in Studio, so the mirror you sync against is current. Never edit `roblox_src/` to change the game — make changes in Studio, then sync.

## Slop check (before building anything)

Before designing or building any mechanic, system, object, or map piece, you MUST open [design/slop/README.md](design/slop/README.md), find what you're building in its routing table, and read every file it lists. Then check the design against those entries and call out any entry it risks. Read only the routed files, not the whole list. When reviewing existing work, use the entry IDs (e.g. "M16") to name the problem. `graphify query "<thing> slop"` can surface related entries too, but the routing table is the authority.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.