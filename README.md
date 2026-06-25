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
| `diagnose_photos_mcp` | Safe MCP capability, logging, install, and Photos permission diagnostics without prompting for Photos access |
| `search_photos` | Search by date range, media type, favorites, keyword |
| `get_album_contents` | Assets in an album by identifier |
| `get_asset_details` | Full metadata for an asset |
| `get_asset_classifications` | Vision classification labels and confidence scores for a photo |
| `get_photo_thumbnail` | Export a small JPEG thumbnail with temp-file text, optional inline image content, and a bounded resource link |
| `get_photo_full` | Export a full or bounded JPEG image to a temp file; bounded exports include a resource link when `max_dimension` is provided |
| `get_photos_by_place` | Photos by place name (e.g. Valencia, Paris)—geocodes and searches |
| `get_photos_by_location` | Photos within a radius of lat/long |
| `get_photos_by_date` | Photos on a date or in a range |
| `list_moments` | Moments/collections (iOS only on macOS) |

Tool definitions use strict MCP `inputSchema` objects with machine-readable defaults, bounds, enums, required fields, and `additionalProperties: false`. Metadata, search, stats, diagnostics, and classification tools also declare MCP `outputSchema` values and return both `structuredContent` and JSON text content. Clients that support structured tool results can read typed data directly; older clients can continue parsing the text JSON. Image export tools return mixed MCP content instead of structured JSON: the first content item remains text for legacy/local clients, thumbnails may include inline image content, and bounded exports include `resource_link` content for resource-capable clients. Image tools do not declare `outputSchema`.

All list/search tools support `limit` (default 50, min 1, max 200) and `offset` (default 0, min 0) for Photos application-level pagination. Paginated responses include `total`, `limit`, `offset`, and `next_offset`; use `next_offset` as the next `offset` value, or stop when it is `null`. This is separate from MCP protocol cursor pagination, which applies to protocol list methods such as `tools/list`, not Photos result tools. Runtime validation rejects unknown arguments and out-of-range values before PhotoKit, geocoding, or image export work begins.

Tool execution errors return `isError: true` with JSON text as the first content item and the same envelope in `_meta.photos_error`. The envelope fields are `code`, `category`, `message`, `retryable`, and `remediation`; categories include `validation`, `permission`, `not_found`, `unsupported_media_type`, `external_service`, `export`, `photokit`, and `internal`. Error envelopes intentionally do not use `structuredContent`, because `structuredContent` is reserved for successful outputs that match each tool's `outputSchema`.

Example validation error:

```json
{
  "code": "validation.required_argument",
  "category": "validation",
  "message": "asset_identifier is required",
  "retryable": true,
  "remediation": "Provide asset_identifier using the tool input schema and retry."
}
```

Unknown tool names are returned as MCP protocol errors (`invalidParams`) instead of tool execution errors. This matches current MCP guidance: malformed or unsupported `tools/call` requests are protocol errors, while recoverable validation, permission, not-found, geocoding, and export failures are tool results with `isError: true`.

## Diagnostics and Logging

PhotosMCP declares the MCP `logging` capability and accepts `logging/setLevel`. The default MCP log threshold is `notice`; clients that support MCP logging can lower or raise it with levels such as `debug`, `info`, `notice`, `warning`, and `error`. Log notifications use names such as `photosmcp.server`, `photosmcp.tool`, `photosmcp.resource`, and `photosmcp.diagnostics`.

Use `diagnose_photos_mcp` when Claude Desktop, Claude Code, or another stdio MCP client cannot see photos or resources. This tool does not request Photos authorization and does not read assets. It returns structured JSON with:

- server version and SDK/spec support note;
- declared MCP capabilities, including tools, resources, and logging;
- current Photos authorization status and required PhotoKit access level;
- tool/resource inventory counts;
- wrapper log hint `${TMPDIR:-/tmp}/photos-mcp.log` when using `scripts/run-photos-mcp.sh`;
- safe next steps for permission and startup troubleshooting.

MCP logs and diagnostics are intentionally categorical. They may include event names, tool names, resource categories, status, duration, error code/category, and authorization status. They should not include asset identifiers, album identifiers, full `photos://` URIs, GPS coordinates, dates, place names, classification labels, exported image bytes, credentials, or temp image paths.

For generic stdio clients, first confirm the configured command starts `.build/release/PhotosMCP`, then call `tools/list` and `diagnose_photos_mcp`. If MCP initialization fails before tools are available, use the wrapper log file above for local process/transport errors.

## MCP Resources

PhotosMCP also exposes MCP resource templates for clients that support `resources/templates/list` and `resources/read`:

- `photos://asset/{asset_identifier}` returns asset metadata JSON as `application/json`.
- `photos://export/{asset_identifier}{?variant,max_dimension,quality}` returns bounded JPEG data as `image/jpeg`. `variant` must be `thumbnail` or `full`, `max_dimension` is required, and `quality` defaults to `0.8` when omitted.

Tool results include `resource_link` entries where useful: asset detail/search results link to metadata resources, thumbnail exports link to bounded thumbnail resources, and full-image exports link to bounded full export resources only when `max_dimension` is provided. Clients without resource support can keep using the existing JSON text, structured content, and temp-file instructions.

Image transfer uses a hybrid contract:

- **Temp-file fallback**: `get_photo_thumbnail` and `get_photo_full` always put human-readable temp-file guidance first, including an `open /path` instruction when saving succeeds.
- **Inline thumbnails**: `get_photo_thumbnail` includes inline MCP image content only when the generated JPEG is at or below 1,500,000 bytes. Larger thumbnails remain available through the temp file and bounded resource link.
- **Bounded resource blobs**: `photos://export/...` resource reads generate `image/jpeg` binary content on demand and require `max_dimension` so MCP payloads stay bounded.
- **Full export boundary**: `get_photo_full` never inlines image content. It includes a full-export `resource_link` only when `max_dimension` is provided; unbounded full-resolution exports remain temp-file only.

## Permissions

The server uses `PHPhotoLibrary.requestAuthorization(for: .readWrite)` and will show a system dialog on first use. PhotoKit's macOS access levels expose add-only and read/write modes; there is no read-only access level that can read existing library assets. PhotosMCP therefore requests read/write Photos authorization as the least available read-capable PhotoKit scope, but the server's own behavior remains read-only. If access is denied, tools return clear error messages.

## Read-Only

This server is read-only. It does not modify, delete, or create assets or albums.

## Privacy & Data

- **Limited Photos access**: If macOS grants limited library access, PhotosMCP can only search, count, list, read, export, and serve resources for assets visible in that limited Photos scope. Assets outside the granted subset may be absent from results or behave like not-found identifiers.
- **Metadata returned to clients**: Tool results and `photos://asset/...` resources may include Photos local identifiers, dates, dimensions, media type/subtypes, favorite and hidden flags, and GPS coordinates when Photos has them.
- **Place search** (`get_photos_by_place`): Place names you provide (e.g. "Valencia", "Paris") are sent to Apple's geocoding service to resolve coordinates. This may involve network requests.
- **iCloud-backed media**: Image export tools and `photos://export/...` resource reads allow PhotoKit network access so iCloud-backed assets can be downloaded from Apple when needed.
- **Image export temp files**: Thumbnails and full images are written to a `PhotosMCP` subdirectory in the system temp folder. Files older than 1 hour are automatically deleted when new exports occur. Thumbnails at or below 1,500,000 bytes may also be sent inline through the MCP tool result.
- **MCP resources**: Metadata and bounded JPEG resources are generated on demand from Photos asset identifiers. Resource URIs do not expose local filesystem paths and cannot read arbitrary temp files, but clients that receive `photos://asset/...` or `photos://export/...` links can see the encoded Photos local identifier.
- **Logging**: Default server and wrapper logs are for transport/process diagnostics. They should not contain photo metadata, GPS coordinates, classifications, exported image contents, or temp export paths beyond user-facing tool results returned to the MCP client.

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
