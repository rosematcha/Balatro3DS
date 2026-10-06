#!/usr/bin/env bash
#
# Run the headless test suite.
#
#   ./tests/run.sh              # everything
#   ./tests/run.sh do_random    # only test files whose name contains "do_random"
#
# Needs luajit on PATH (or set LUAJIT). There is no `love` binary involved: the
# suite loads the game against tests/love_stub.lua.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LUAJIT="${LUAJIT:-}"
if [ -z "$LUAJIT" ]; then
    for candidate in luajit /opt/homebrew/bin/luajit /usr/local/bin/luajit; do
        if command -v "$candidate" >/dev/null 2>&1; then
            LUAJIT="$candidate"
            break
        fi
    done
fi

if [ -z "$LUAJIT" ]; then
    echo "luajit not found. Install it (brew install luajit / apt-get install luajit) or set LUAJIT." >&2
    exit 127
fi

# Game modules are required by bare name ("card", "hand"), so the repo root has to
# be on the Lua path alongside the tests/ package directory.
export LUA_PATH="$ROOT/?.lua;$ROOT/?/init.lua;;"
export BALATRO_ROOT="$ROOT"

exec "$LUAJIT" tests/runner.lua "$@"
