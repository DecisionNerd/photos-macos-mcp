---
name: MCP compatibility review
about: Review MCP Swift SDK and MCP spec drift
title: "Review MCP Swift SDK/spec compatibility"
labels: enhancement
assignees: ""
---

## Review Trigger

- [ ] New `modelcontextprotocol/swift-sdk` release
- [ ] New MCP spec date or capability guidance
- [ ] Client interoperability regression
- [ ] Scheduled/manual compatibility audit

## Current Values

- Expected Swift SDK version: `0.12.1`
- Expected MCP spec date: `2025-11-25`
- Compatibility doc: `docs/mcp-compatibility.md`
- CI/script guardrail: `scripts/check_mcp_compatibility.sh`

## Checklist

- [ ] Run `swift package show-dependencies`.
- [ ] Compare `Package.swift` and `Package.resolved` against the latest reviewed SDK version.
- [ ] Review MCP Tools, Resources, Logging, and schema guidance for changed requirements.
- [ ] Update `ServerMetadata.sdkSpecSupport` if SDK/spec values change.
- [ ] Update `docs/mcp-compatibility.md` capability matrix and resolved SDK revision.
- [ ] Update `scripts/check_mcp_compatibility.sh` expected constants if the change is intentional.
- [ ] Re-run `swift test`, `swift build -c release`, `bash -n scripts/*.sh`, and `./scripts/check_mcp_compatibility.sh`.
- [ ] Re-check client docs for Claude Desktop, Claude Code, Codex, Cursor, Windsurf/Cascade, ChatGPT/OpenAI MCP limitations, and generic stdio clients.

## Notes

Remote hosted MCP remains out of scope unless a separate security, authentication, authorization, and privacy design is accepted.
