# MCP Compatibility

This document records the MCP SDK/spec boundary that PhotosMCP is built and tested against. Update it whenever `Package.resolved`, `Package.swift`, MCP spec guidance, or server capabilities change.

## Current Tracking Values

| Item | Current value |
| --- | --- |
| Swift SDK package | `modelcontextprotocol/swift-sdk` |
| Package requirement | `from: "0.12.1"` |
| Resolved SDK version | `0.12.1` |
| Resolved SDK revision | `a0ae212ebf6eab5f754c3129608bc5557637e605` |
| MCP spec date tracked by server diagnostics | `2025-11-25` |
| Transport scope | Local stdio |

PhotosMCP is local-first. Remote hosted MCP, HTTP transport, OAuth, and network exposure of a personal Photos library are out of scope unless a separate security and privacy design is accepted later.

In short: structured content, resources, and logging are supported; prompts, task execution, and remote hosted MCP are not implemented.

## Capability Matrix

| Capability or pattern | Status | Notes |
| --- | --- | --- |
| Tools | Supported | All Photos operations are exposed as read-only MCP tools. |
| Strict input schemas | Supported | Tool input schemas use bounded JSON Schema objects with `additionalProperties: false`. |
| Output schemas | Supported | Metadata, search, stats, diagnostics, and classification tools declare `outputSchema`. |
| Structured content | Supported | Structured tools return `structuredContent` and JSON text for legacy clients. |
| Typed tool errors | Supported | Tool execution errors use JSON text plus `_meta.photos_error`; unknown tools use protocol errors. |
| Resources | Supported | `photos://asset/...` metadata and bounded `photos://export/...` JPEG resources are available. |
| Resource links | Supported | Tool results include resource links where useful and bounded. |
| Image content | Partially supported | Thumbnails may inline small JPEGs; full exports are temp-file/resource-link based. |
| Logging | Supported | Server declares MCP `logging` and accepts `logging/setLevel`. |
| Diagnostics tool | Supported | `diagnose_photos_mcp` reports safe capability and permission status without prompting for Photos access. |
| Prompts | Not implemented | No MCP prompt capability is declared. |
| Completions | Not implemented | No MCP completions capability is declared. |
| Elicitation | Not implemented | No client elicitation flow is used. |
| Task execution | Not implemented / future pattern | No MCP task-execution surface is declared. |
| Roots | Not implemented | PhotosMCP does not request client filesystem roots. |
| HTTP transport | Not implemented | The server currently uses local stdio transport only. |
| Remote hosted MCP | Out of scope | Local macOS Photos privacy and permission boundaries are not designed for hosted exposure. |

## Drift Review Checklist

Run this checklist when a new MCP Swift SDK release, MCP spec date, or major MCP client behavior change appears:

1. Run `swift package update modelcontextprotocol` only on an intentional compatibility branch.
2. Run `swift package show-dependencies` and update the resolved SDK version/revision above.
3. Review MCP Tools, Resources, Logging, and schema references for changed requirements.
4. Verify `ServerMetadata.sdkSpecSupport` and `scripts/check_mcp_compatibility.sh` constants match the reviewed SDK/spec.
5. Re-check tool schemas, structured content, resource links, binary/image behavior, typed errors, and diagnostics against modern clients.
6. Update README/client setup docs if client interoperability or local stdio assumptions change.
7. Run `swift test`, `swift build -c release`, `bash -n scripts/*.sh`, and `./scripts/check_mcp_compatibility.sh`.

## CI Guardrail

`scripts/check_mcp_compatibility.sh` parses `Package.resolved`, checks the expected Swift SDK version, verifies the MCP spec date in server diagnostics metadata, and prints `swift package show-dependencies`. It is intentionally strict: if SDK/spec values drift, update this document, the script constants, and relevant implementation/tests in the same PR.
