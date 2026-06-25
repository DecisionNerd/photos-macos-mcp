#!/bin/bash
# Wrapper to run PhotosMCP and capture stderr process/transport diagnostics.
# MCP logging is emitted through the protocol when the client supports it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$REPO_ROOT/.build/release/PhotosMCP"
LOGFILE="${TMPDIR:-/tmp}/photos-mcp.log"

if [[ ! -x "$BIN" ]]; then
  echo "PhotosMCP release binary not found. Build it first with: swift build -c release" >&2
  exit 1
fi

exec 2>>"$LOGFILE"
echo "--- PhotosMCP started $(date) ---" >>"$LOGFILE"
exec "$BIN" "$@"
