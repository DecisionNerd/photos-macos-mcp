# Client Setup Matrix

PhotosMCP is a local stdio MCP server. Build it first, then configure each client to launch the release binary with an absolute path.

```bash
swift build -c release
test -x .build/release/PhotosMCP
```

Replace `/absolute/path/to/photos-macos-mcp/.build/release/PhotosMCP` in the examples below with your real binary path, or use `~/.local/bin/PhotosMCP` after running `./scripts/install.sh`.

## Shared Photos Caveats

- PhotosMCP requests PhotoKit `.readWrite` permission because macOS does not expose a read-only access level for reading existing Photos assets. The server behavior remains read-only.
- Grant Photos access to the app or process that launches PhotosMCP, such as Claude Desktop, Cursor, Windsurf, Codex, or a terminal/MCP Inspector process.
- Limited Photos library access means tools, resources, counts, and exports only see the assets macOS exposes to that client.
- Tool results may include Photos metadata such as local identifiers, dates, dimensions, favorite/hidden flags, and GPS coordinates. Keep local MCP client sharing settings in mind.

## Status Matrix

| Client | Local stdio PhotosMCP status | Verification status |
| --- | --- | --- |
| Claude Desktop | Supported with JSON config or `scripts/install.sh` | Config shape documented and script-supported |
| Claude Code | Supported with `claude mcp add` or `scripts/install.sh` | Command shape documented and script-supported |
| Codex | Supported by stdio config | Documentation-sourced, not locally verified in this issue |
| Cursor | Supported by MCP JSON config | Documentation-sourced, not locally verified in this issue |
| Windsurf/Cascade | Supported by MCP JSON config | Documentation-sourced, not locally verified in this issue |
| ChatGPT/OpenAI MCP | Local stdio is not directly applicable | Remote MCP only; out of scope |
| Generic stdio/MCP Inspector | Supported when the client can launch a local command | Smoke-check locally where available |

## Claude Desktop

The convenience installer can build, install, and update Claude Desktop config:

```bash
./scripts/install.sh
```

Manual config lives at `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/photos-macos-mcp/.build/release/PhotosMCP",
      "args": []
    }
  }
}
```

Restart Claude Desktop after editing config. If PhotosMCP cannot access the library, grant Photos access to Claude Desktop in System Settings > Privacy & Security > Photos, then restart Claude Desktop again.

## Claude Code

The convenience installer also registers Claude Code when the `claude` CLI is available:

```bash
./scripts/install.sh
```

Manual registration:

```bash
claude mcp add --scope user photos -- /absolute/path/to/photos-macos-mcp/.build/release/PhotosMCP
claude mcp get photos
```

Inside Claude Code, use `/mcp` to inspect connected MCP servers. If access is denied, grant Photos access to the terminal app or Claude Code host process that launches the server.

## Codex

Add a stdio server entry to `~/.codex/config.toml`:

```toml
[mcp_servers.photos]
command = "/absolute/path/to/photos-macos-mcp/.build/release/PhotosMCP"
args = []
startup_timeout_sec = 20
tool_timeout_sec = 120
```

Restart Codex after editing config. Verify by listing MCP tools or calling `diagnose_photos_mcp` from a Codex session. Grant Photos access to the Codex app or terminal process that starts the server.

## Cursor

Cursor supports MCP server definitions through an MCP JSON config. Add PhotosMCP as a stdio server:

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/photos-macos-mcp/.build/release/PhotosMCP",
      "args": []
    }
  }
}
```

Refresh MCP servers or restart Cursor after editing config. Verify that the `photos` server appears, then call `diagnose_photos_mcp`. Grant Photos access to Cursor if macOS prompts or the diagnostics tool reports denied access.

## Windsurf / Cascade

Windsurf/Cascade MCP config commonly lives at `~/.codeium/mcp_config.json`:

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/photos-macos-mcp/.build/release/PhotosMCP",
      "args": []
    }
  }
}
```

Refresh MCP servers or restart Windsurf after editing config. Verify that the `photos` server appears, then call `diagnose_photos_mcp`. Grant Photos access to Windsurf/Cascade if macOS prompts or diagnostics reports denied access.

## ChatGPT / OpenAI MCP

PhotosMCP is a local stdio server for a private macOS Photos library. Hosted ChatGPT/OpenAI MCP workflows expect a remote MCP server URL rather than a local stdio command, so PhotosMCP is not directly usable there as-is.

Remote-hosted Photos access is out of scope for this repository. Do not expose a personal Photos library over a network without a separate security, authentication, authorization, and privacy design.

## Generic Stdio Clients and MCP Inspector

Any MCP client that can launch a local stdio command can use the release binary:

```json
{
  "mcpServers": {
    "photos": {
      "command": "/absolute/path/to/photos-macos-mcp/.build/release/PhotosMCP",
      "args": []
    }
  }
}
```

Minimum verification sequence:

1. Start the server through the client.
2. Confirm `tools/list` includes `diagnose_photos_mcp`, `get_library_stats`, and `search_photos`.
3. Call `diagnose_photos_mcp`; it should return server capabilities and current Photos authorization status without prompting for Photos access.
4. If authorized, call `get_library_stats` or `search_photos` with a small `limit`.

If MCP initialization fails before tools are available and you launched through `scripts/run-photos-mcp.sh`, check `${TMPDIR:-/tmp}/photos-mcp.log` for local process or transport errors. MCP protocol logs are separate and only appear in clients that support MCP `logging`.
