"""Fingerprint roblox_src/ the same way tools/studio_fingerprint.luau fingerprints Studio.

Usage:
  python tools/local_fingerprint.py              # print local fingerprints as JSON
  python tools/local_fingerprint.py --save       # write roblox_src/.sync_manifest.json
  python tools/local_fingerprint.py --diff FILE  # compare Studio JSON (saved to FILE) with the manifest
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "roblox_src"
MANIFEST = ROOT / ".sync_manifest.json"


def fingerprint(data: bytes) -> str:
    h = 5381
    for b in data:
        h = (h * 33 + b) % 4294967296
    return f"{data.count(b'\n') + 1}:{h:08x}"


def local() -> dict:
    return {p.relative_to(ROOT).as_posix(): fingerprint(p.read_bytes()) for p in sorted(ROOT.rglob("*.luau"))}


def main() -> None:
    args = sys.argv[1:]
    if args[:1] == ["--save"]:
        MANIFEST.write_text(json.dumps(local(), indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"wrote {MANIFEST}")
    elif args[:1] == ["--diff"]:
        studio = json.loads(pathlib.Path(args[1]).read_text(encoding="utf-8"))
        known = json.loads(MANIFEST.read_text(encoding="utf-8"))
        changed = sorted(k for k in studio if k in known and studio[k] != known[k])
        added = sorted(set(studio) - set(known))
        removed = sorted(set(known) - set(studio))
        for label, items in (("changed", changed), ("added", added), ("removed", removed)):
            for k in items:
                print(f"{label}: {k}")
        print("IN SYNC" if not (changed or added or removed) else "OUT OF SYNC")
    else:
        print(json.dumps(local(), indent=2, sort_keys=True))


main()
