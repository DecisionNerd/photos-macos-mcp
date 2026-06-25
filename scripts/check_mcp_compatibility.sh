#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SWIFT_SDK_VERSION="0.12.1"
EXPECTED_MCP_SPEC_DATE="2025-11-25"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_file="$repo_root/Package.swift"
resolved_file="$repo_root/Package.resolved"
metadata_file="$repo_root/Sources/PhotosMCP/Helpers/ServerMetadata.swift"

fail() {
  printf 'MCP compatibility check failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest_file" ]] || fail "Package.swift not found"
[[ -f "$resolved_file" ]] || fail "Package.resolved not found"
[[ -f "$metadata_file" ]] || fail "ServerMetadata.swift not found"

read -r sdk_version sdk_revision < <(python3 - "$resolved_file" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

for pin in data.get("pins", []):
    if pin.get("identity") == "swift-sdk":
        state = pin.get("state", {})
        print(state.get("version", ""), state.get("revision", ""))
        break
else:
    raise SystemExit("swift-sdk pin not found")
PY
)

[[ -n "$sdk_version" ]] || fail "swift-sdk version missing from Package.resolved"
[[ "$sdk_version" == "$EXPECTED_SWIFT_SDK_VERSION" ]] || fail "expected swift-sdk $EXPECTED_SWIFT_SDK_VERSION, found $sdk_version"

if ! grep -q "swift-sdk.git\", from: \"$EXPECTED_SWIFT_SDK_VERSION\"" "$manifest_file"; then
  fail "Package.swift does not require swift-sdk from $EXPECTED_SWIFT_SDK_VERSION"
fi

if ! grep -q "swift-sdk $EXPECTED_SWIFT_SDK_VERSION" "$metadata_file"; then
  fail "ServerMetadata.sdkSpecSupport does not mention swift-sdk $EXPECTED_SWIFT_SDK_VERSION"
fi

if ! grep -q "MCP spec $EXPECTED_MCP_SPEC_DATE" "$metadata_file"; then
  fail "ServerMetadata.sdkSpecSupport does not mention MCP spec $EXPECTED_MCP_SPEC_DATE"
fi

printf 'MCP compatibility tracking\n'
printf '  swift-sdk version: %s\n' "$sdk_version"
printf '  swift-sdk revision: %s\n' "$sdk_revision"
printf '  MCP spec date: %s\n' "$EXPECTED_MCP_SPEC_DATE"
printf '\nSwift package dependency tree:\n'
swift package show-dependencies --package-path "$repo_root"
