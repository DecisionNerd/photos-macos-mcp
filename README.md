# PhotosMCP

A **Model Context Protocol (MCP) server** in Swift that provides AI assistants with read-only access to the macOS Photos library via Apple's PhotoKit framework.

## Requirements

- macOS 26.0+
- Swift 6.2+ (Xcode 26+)
- Photos app with a library

## Building

```bash
swift build -c release
```

The executable will be at:

```
.build/release/PhotosMCP
```

## Convenience Scripts

Install from source and register the MCP server with Claude Desktop and Claude Code:

```bash
./scripts/install.sh
```

One-click rebuild and reinstall for local development:

```bash
./scripts/rebuild_reinstall.sh
```

Remove Claude registrations and the installed binary:

```bash
./scripts/uninstall.sh
```

Update Swift package dependencies:

```bash
./scripts/update_deps.sh
```

By default, the installer uses server name `photos` and installs the binary to `~/.local/bin/PhotosMCP`. You can override these with:

```bash
./scripts/install.sh --name photos --install-dir "$HOME/.local/bin" --scope user
```

## Claude Desktop App Integration

1. **Build the project** (see above).

2. **Add to Claude Desktop config**

   Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

   ```json
   {
     "mcpServers": {
       "photos": {
         "command": "/Users/YOUR_USERNAME/Developer/photos-macos-mcp/.build/release/PhotosMCP",
         "args": []
       }
     }
   }
   ```

   Replace `YOUR_USERNAME` (or the whole path) with the actual absolute path to your built binary, for example:

```json
"command": "/Users/max/Developer/photos-macos-mcp/.build/release/PhotosMCP"
```

3. **Grant Photos access**

   The PhotosMCP process (or the parent Claude app) needs access to your Photos library. If prompted, allow it in:

   **System Settings → Privacy & Security → Photos**

   If the server was spawned by the Claude desktop app, you may need to grant Photos access to the Claude app.

4. **Restart Claude** so it picks up the new MCP server.

## MCP Tools

| Tool | Description |
|------|-------------|
| `list_albums` | List all user and smart albums (name, id, asset count, type) |
| `get_library_stats` | Total photos, videos, albums, and date range |
| `search_photos` | Search by date range, media type, favorites, keyword |
| `get_album_contents` | Assets in an album by identifier |
| `get_asset_details` | Full metadata for an asset |
| `get_asset_classifications` | Vision classification labels and confidence scores for a photo |
| `get_photo_thumbnail` | Export a small JPEG thumbnail to a temporary file |
| `get_photo_full` | Export a full-resolution JPEG image to a temporary file |
| `get_photos_by_place` | Photos by place name (e.g. Valencia, Paris)—geocodes and searches |
| `get_photos_by_location` | Photos within a radius of lat/long |
| `get_photos_by_date` | Photos on a date or in a range |
| `list_moments` | Moments/collections (iOS only on macOS) |

Tool definitions use strict MCP `inputSchema` objects with machine-readable defaults, bounds, enums, required fields, and `additionalProperties: false`. Metadata, search, stats, and classification tools also declare MCP `outputSchema` values and return both `structuredContent` and JSON text content. Clients that support structured tool results can read typed data directly; older clients can continue parsing the text JSON. Image export tools are intentionally text/temp-file based for now and do not declare structured output.

All list/search tools support `limit` (default 50, min 1, max 200) and `offset` (default 0, min 0) for Photos application-level pagination. Paginated responses include `total`, `limit`, `offset`, and `next_offset`; use `next_offset` as the next `offset` value, or stop when it is `null`. This is separate from MCP protocol cursor pagination, which applies to protocol list methods such as `tools/list`, not Photos result tools. Runtime validation rejects unknown arguments and out-of-range values before PhotoKit, geocoding, or image export work begins.

## Permissions

The server uses `PHPhotoLibrary.requestAuthorization` and will show a system dialog on first use. If access is denied, tools return clear error messages.

## Read-Only

This server is read-only. It does not modify, delete, or create assets or albums.

## Privacy & Data

- **Place search** (`get_photos_by_place`): Place names you provide (e.g. "Valencia", "Paris") are sent to Apple's geocoding service to resolve coordinates. This may involve network requests.
- **Image export**: Thumbnails and full images are written to a `PhotosMCP` subdirectory in the system temp folder. Files older than 1 hour are automatically deleted when new exports occur.

## Project Structure

```
PhotosMCP/
├── Package.swift
├── Info.plist              # NSPhotoLibraryUsageDescription for Photos access
├── Sources/
│   └── PhotosMCP/
│       ├── main.swift              # Entry point, stdio transport
│       ├── PhotosServer.swift      # MCP server, tool registration
│       ├── Tools/
│       │   ├── ToolDefinitions.swift  # Tool schemas
│       │   ├── LibraryTools.swift    # list_albums, get_library_stats, list_moments
│       │   ├── SearchTools.swift     # search_photos, get_photos_by_location, get_photos_by_date
│       │   ├── AlbumTools.swift      # get_album_contents
│       │   ├── AssetTools.swift      # get_asset_details
│       │   └── ImageTools.swift      # get_photo_thumbnail, get_photo_full
│       └── Helpers/
│           ├── PhotoKitHelpers.swift  # PHAsset → JSON structs
│           ├── ImageExport.swift      # PHImageManager, JPEG export
│           ├── PhotosAccess.swift     # Library authorization
│           ├── DateParsing.swift      # ISO 8601 date parsing
│           ├── GeoUtils.swift         # Haversine distance for location search
│           └── ContentClassifier.swift # Vision ML keyword matching
└── README.md
```

## Notes

- `list_moments` returns an empty list on macOS; the `fetchMoments` API is iOS-only.
- **Keyword search** in `search_photos` uses Vision ML (pizza, food, car, city, dog, beach, etc.). Analyzes up to 1000 photos—combine with date range for large libraries. Some keywords fall back to broader terms (for example, pizza can fall back to food/meal/dish) when the exact pass has no matches.
- **Classification inspection** via `get_asset_classifications` returns the top Vision labels for one photo. Use it to debug why a keyword search did or did not match a photo.
- **Place search** via `get_photos_by_place`—geocodes "Valencia", "Paris" etc. and finds photos taken there.
- **Date search** accepts `yyyy-MM-dd` or full ISO 8601. Use `start_date` and `end_date` for ranges.

## License

MIT
