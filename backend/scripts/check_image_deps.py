#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["packaging"]
# ///
"""Verify a built Docker image's installed Python packages match backend/uv.lock.

Used in CI (the docker job in .github/workflows/ci.yml) to catch drift between
the locked dependency set the backend job tests against and what the
production image (vorrat/Dockerfile) actually ships.

Run via `uv run backend/scripts/check_image_deps.py <image>` so the
`packaging` dependency (needed to evaluate environment markers like
`sys_platform == 'win32'`) is available without polluting the project venv.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from packaging.requirements import Requirement

BACKEND_DIR = Path(__file__).resolve().parents[1]


def _normalize(name: str) -> str:
    # PEP 503-style normalization so "pydantic_core" (dist-info) and
    # "pydantic-core" (uv.lock) compare equal.
    return name.lower().replace("_", "-")


def locked_versions() -> dict[str, str]:
    result = subprocess.run(
        ["uv", "export", "--frozen", "--no-dev", "--no-emit-project", "--no-hashes"],
        cwd=BACKEND_DIR,
        check=True,
        capture_output=True,
        text=True,
    )
    versions: dict[str, str] = {}
    for line in result.stdout.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        req = Requirement(line)
        # Skip requirements whose environment marker doesn't apply here (e.g.
        # colorama is sys_platform == 'win32' only, pulled in by click) — the
        # image is built for Linux, same as the CI runner running this check.
        if req.marker is not None and not req.marker.evaluate():
            continue
        versions[_normalize(req.name)] = str(req.specifier).removeprefix("==")
    return versions


def image_versions(image: str) -> dict[str, str]:
    probe = (
        "import importlib.metadata as m, json;"
        "print(json.dumps({d.metadata['Name']: d.version"
        " for d in m.distributions()}))"
    )
    result = subprocess.run(
        ["docker", "run", "--rm", "--entrypoint", "python3", image, "-c", probe],
        check=True,
        capture_output=True,
        text=True,
    )
    return {_normalize(name): version for name, version in json.loads(result.stdout).items()}


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <image>", file=sys.stderr)
        return 2
    image = sys.argv[1]

    locked = locked_versions()
    installed = image_versions(image)

    mismatches = [
        f"  {name}: locked={version!r} image={installed.get(name)!r}"
        for name, version in sorted(locked.items())
        if installed.get(name) != version
    ]
    if mismatches:
        print(
            f"Image '{image}' dependency versions do not match backend/uv.lock:",
            file=sys.stderr,
        )
        print("\n".join(mismatches), file=sys.stderr)
        return 1

    print(f"OK: all {len(locked)} locked packages match the built image.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
