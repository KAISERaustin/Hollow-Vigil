#!/usr/bin/env python3
"""Check source resource links, script identities and the gameplay/presentation boundary."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    failures = []
    identities = {}
    for directory in ("scripts", "tests", "scenes"):
        for path in sorted((ROOT / directory).rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(ROOT).as_posix()
            if path.suffix == ".uid":
                identity = path.read_text().strip()
                if identity in identities:
                    failures.append(f"Duplicate UID: {relative} and {identities[identity]}")
                identities[identity] = relative
                if not path.with_suffix("").is_file():
                    failures.append(f"Orphan UID: {relative}")
            if path.suffix not in (".gd", ".tscn", ".gdshader"):
                continue
            source = path.read_text()
            for resource in re.findall(r'[\"\']res://([^\"\'\n]+)[\"\']', source):
                # Output artifacts are intentionally created at runtime.
                if resource.startswith(("artifacts/", ".runtime/")) or "%" in resource:
                    continue
                if not (ROOT / resource).exists():
                    failures.append(f"Missing resource in {relative}: {resource}")
                if relative.startswith("scripts/gameplay/") and resource.startswith(
                    ("scripts/rendering/", "scripts/ui/", "scripts/app/")
                ):
                    failures.append(f"Gameplay imports presentation in {relative}: {resource}")
    for failure in failures:
        print(failure, file=sys.stderr)
    print(f"Structure checks: {len(failures)} failures")
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
