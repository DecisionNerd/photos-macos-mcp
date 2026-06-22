import MCP

/// Tool schema definitions for MCP registration.
enum ToolDefinitions {

    static func schema(
        properties: [String: Value],
        required: [String]? = nil
    ) -> Value {
        var obj: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false)
        ]
        if let required = required, !required.isEmpty {
            obj["required"] = .array(required.map { .string($0) })
        }
        return .object(obj)
    }

    static func prop(
        _ type: String,
        description: String,
        enumValues: [String]? = nil,
        defaultValue: Value? = nil,
        minimum: Value? = nil,
        maximum: Value? = nil,
        exclusiveMinimum: Value? = nil
    ) -> Value {
        var p: [String: Value] = [
            "type": .string(type),
            "description": .string(description)
        ]
        if let enumValues = enumValues {
            p["enum"] = .array(enumValues.map { .string($0) })
        }
        if let defaultValue {
            p["default"] = defaultValue
        }
        if let minimum {
            p["minimum"] = minimum
        }
        if let maximum {
            p["maximum"] = maximum
        }
        if let exclusiveMinimum {
            p["exclusiveMinimum"] = exclusiveMinimum
        }
        return .object(p)
    }

    private static let dateDescription = "Date as yyyy-MM-dd or ISO 8601 datetime with timezone, e.g. 2024-01-15 or 2024-01-15T14:30:00Z"

    private static func limitProp(_ description: String = "Maximum results to return") -> Value {
        prop(
            "integer",
            description: "\(description) (default 50, min 1, max 200)",
            defaultValue: .int(50),
            minimum: .int(1),
            maximum: .int(200)
        )
    }

    private static func offsetProp() -> Value {
        prop(
            "integer",
            description: "Number of results to skip for application-level pagination (default 0, min 0)",
            defaultValue: .int(0),
            minimum: .int(0)
        )
    }

    private static func qualityProp() -> Value {
        prop(
            "number",
            description: "JPEG quality from 0.0 to 1.0 (default 0.8)",
            defaultValue: .double(0.8),
            minimum: .double(0.0),
            maximum: .double(1.0)
        )
    }

    private static func maxDimensionProp(defaultValue: Int? = nil, description: String) -> Value {
        var defaultSchema: Value?
        if let defaultValue {
            defaultSchema = .int(defaultValue)
        }
        return prop(
            "integer",
            description: description,
            defaultValue: defaultSchema,
            minimum: .int(1)
        )
    }

    private static func radiusProp(defaultValue: Double) -> Value {
        prop(
            "number",
            description: "Search radius in kilometers (default \(defaultValue), must be greater than 0)",
            defaultValue: .double(defaultValue),
            exclusiveMinimum: .double(0.0)
        )
    }

    private static func dateProp(_ description: String) -> Value {
        prop("string", description: "\(description). \(dateDescription)")
    }

    private static func object(_ properties: [String: Value], required: [String] = []) -> Value {
        var schema: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        return .object(schema)
    }

    private static func array(_ items: Value) -> Value {
        .object([
            "type": .string("array"),
            "items": items
        ])
    }

    private static func type(_ name: String, description: String? = nil) -> Value {
        var schema: [String: Value] = ["type": .string(name)]
        if let description {
            schema["description"] = .string(description)
        }
        return .object(schema)
    }

    private static func nullable(_ names: [String]) -> Value {
        .object(["type": .array(names.map { .string($0) })])
    }

    private static let nextOffsetSchema = nullable(["integer", "null"])

    private static let locationSchema = object([
        "latitude": type("number"),
        "longitude": type("number")
    ], required: ["latitude", "longitude"])

    private static let assetSchema = object([
        "identifier": type("string"),
        "creationDate": nullable(["string", "null"]),
        "modificationDate": nullable(["string", "null"]),
        "mediaType": type("string"),
        "mediaSubtypes": array(type("string")),
        "pixelWidth": type("integer"),
        "pixelHeight": type("integer"),
        "duration": nullable(["number", "null"]),
        "isFavorite": type("boolean"),
        "isHidden": type("boolean"),
        "location": .object(["anyOf": .array([locationSchema, .object(["type": .string("null")])])]),
        "resourceFileSizes": .object(["anyOf": .array([array(type("integer")), .object(["type": .string("null")])])])
    ], required: [
        "identifier",
        "creationDate",
        "modificationDate",
        "mediaType",
        "mediaSubtypes",
        "pixelWidth",
        "pixelHeight",
        "duration",
        "isFavorite",
        "isHidden",
        "location",
        "resourceFileSizes"
    ])

    private static let searchResponseSchema = object([
        "assets": array(assetSchema),
        "total": type("integer"),
        "limit": type("integer"),
        "offset": type("integer"),
        "next_offset": nextOffsetSchema
    ], required: ["assets", "total", "limit", "offset", "next_offset"])

    private static let keywordInfoSchema = object([
        "requestedKeyword": type("string"),
        "matchedKeyword": nullable(["string", "null"]),
        "usedFallback": type("boolean"),
        "fallbackKeywords": array(type("string")),
        "confidenceThreshold": type("number"),
        "analyzedAssets": type("integer"),
        "maxAnalyzedAssets": type("integer")
    ], required: [
        "requestedKeyword",
        "matchedKeyword",
        "usedFallback",
        "fallbackKeywords",
        "confidenceThreshold",
        "analyzedAssets",
        "maxAnalyzedAssets"
    ])

    private static let searchWithKeywordInfoSchema = object([
        "assets": array(assetSchema),
        "total": type("integer"),
        "limit": type("integer"),
        "offset": type("integer"),
        "next_offset": nextOffsetSchema,
        "keywordInfo": .object(["anyOf": .array([keywordInfoSchema, .object(["type": .string("null")])])])
    ], required: ["assets", "total", "limit", "offset", "next_offset", "keywordInfo"])

    private static let albumListSchema = object([
        "albums": array(object([
            "identifier": type("string"),
            "name": type("string"),
            "asset_count": type("integer"),
            "type": type("string")
        ], required: ["identifier", "name", "asset_count", "type"])),
        "total": type("integer"),
        "limit": type("integer"),
        "offset": type("integer"),
        "next_offset": nextOffsetSchema
    ], required: ["albums", "total", "limit", "offset", "next_offset"])

    private static let libraryStatsSchema = object([
        "photos": type("integer"),
        "videos": type("integer"),
        "total_assets": type("integer"),
        "albums": type("integer"),
        "date_range": object([
            "earliest": nullable(["string", "null"]),
            "latest": nullable(["string", "null"])
        ], required: ["earliest", "latest"])
    ], required: ["photos", "videos", "total_assets", "albums", "date_range"])

    private static let momentListSchema = object([
        "moments": array(object([
            "identifier": type("string"),
            "title": nullable(["string", "null"]),
            "start_date": nullable(["string", "null"]),
            "end_date": nullable(["string", "null"]),
            "location_names": array(type("string")),
            "asset_count": type("integer")
        ], required: ["identifier", "title", "start_date", "end_date", "location_names", "asset_count"])),
        "total": type("integer"),
        "limit": type("integer"),
        "offset": type("integer"),
        "next_offset": nextOffsetSchema
    ], required: ["moments", "total", "limit", "offset", "next_offset"])

    private static let classificationSchema = object([
        "assetIdentifier": type("string"),
        "classifications": array(object([
            "label": type("string"),
            "confidence": type("number")
        ], required: ["label", "confidence"]))
    ], required: ["assetIdentifier", "classifications"])

    private static let placeSearchSchema = object([
        "place": object([
            "name": type("string"),
            "latitude": type("number"),
            "longitude": type("number"),
            "radius_km": type("number")
        ], required: ["name", "latitude", "longitude", "radius_km"]),
        "assets": array(assetSchema),
        "total": type("integer"),
        "limit": type("integer"),
        "offset": type("integer"),
        "next_offset": nextOffsetSchema
    ], required: ["place", "assets", "total", "limit", "offset", "next_offset"])

    static var all: [Tool] {
        [
            Tool(
                name: "list_albums",
                description: "Return all user albums and smart albums with name, identifier, asset count, type, and application-level pagination metadata.",
                inputSchema: schema(properties: [
                    "limit": limitProp("Maximum number of albums to return"),
                    "offset": offsetProp()
                ]),
                annotations: .init(readOnlyHint: true),
                outputSchema: albumListSchema
            ),
            Tool(
                name: "get_library_stats",
                description: "Return total counts of photos, videos, albums, and date range of the library.",
                inputSchema: schema(properties: [:]),
                annotations: .init(readOnlyHint: true),
                outputSchema: libraryStatsSchema
            ),
            Tool(
                name: "search_photos",
                description: "Search the Photos library by date range, media type, favorite status, or keyword with application-level pagination metadata.",
                inputSchema: schema(properties: [
                    "start_date": dateProp("Start of date range"),
                    "end_date": dateProp("End of date range"),
                    "media_type": prop("string", description: "Filter by media type (default any)", enumValues: ["photo", "video", "live_photo", "any"], defaultValue: .string("any")),
                    "is_favorite": prop("boolean", description: "Filter to favorites only"),
                    "keyword": prop("string", description: "Filter by visual content (pizza, food, car, city, dog, beach, etc.). Uses Vision ML. Combine with date range for large libraries."),
                    "limit": limitProp(),
                    "offset": offsetProp()
                ]),
                annotations: .init(readOnlyHint: true),
                outputSchema: searchWithKeywordInfoSchema
            ),
            Tool(
                name: "get_album_contents",
                description: "Return asset metadata for items in a given album by album identifier with application-level pagination metadata.",
                inputSchema: schema(properties: [
                    "album_identifier": prop("string", description: "The album's local identifier"),
                    "limit": limitProp(),
                    "offset": offsetProp()
                ], required: ["album_identifier"]),
                annotations: .init(readOnlyHint: true),
                outputSchema: searchResponseSchema
            ),
            Tool(
                name: "get_asset_details",
                description: "Return full metadata for an asset: EXIF, dates, GPS, dimensions, media subtypes, duration (video), resource sizes.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier")
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true),
                outputSchema: assetSchema
            ),
            Tool(
                name: "get_asset_classifications",
                description: "Return Vision image classification labels and confidence scores for a photo. Useful when keyword search misses an expected object.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier"),
                    "max_results": prop("integer", description: "Maximum classification labels to return (default 10, min 1, max 30)", defaultValue: .int(10), minimum: .int(1), maximum: .int(30))
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true),
                outputSchema: classificationSchema
            ),
            Tool(
                name: "get_photo_thumbnail",
                description: "Small preview (default 512px). Returns temp-file text first, may include inline JPEG image content when under 1.5 MB, and includes a bounded resource_link for portable MCP clients.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier"),
                    "max_dimension": maxDimensionProp(defaultValue: 512, description: "Maximum width or height in pixels (default 512, min 1)"),
                    "quality": qualityProp()
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_photo_full",
                description: "Full image export. Always returns temp-file text first and never inline image content; includes a bounded resource_link only when max_dimension is provided for portable MCP transfer.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier"),
                    "max_dimension": maxDimensionProp(description: "Optional max width/height to downscale (min 1; avoids huge payloads)"),
                    "quality": qualityProp()
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_photos_by_place",
                description: "Find photos by place name (city, country). Geocodes the name and returns nearby photos with application-level pagination metadata.",
                inputSchema: schema(properties: [
                    "place": prop("string", description: "Place name (e.g. 'Valencia', 'New York', 'Paris, France')"),
                    "radius_km": radiusProp(defaultValue: 25),
                    "limit": limitProp(),
                    "offset": offsetProp()
                ], required: ["place"]),
                annotations: .init(readOnlyHint: true),
                outputSchema: placeSearchSchema
            ),
            Tool(
                name: "get_photos_by_location",
                description: "Find photos within a radius (km) of given latitude and longitude coordinates with application-level pagination metadata.",
                inputSchema: schema(properties: [
                    "latitude": prop("number", description: "Center latitude in decimal degrees", minimum: .double(-90), maximum: .double(90)),
                    "longitude": prop("number", description: "Center longitude in decimal degrees", minimum: .double(-180), maximum: .double(180)),
                    "radius_km": radiusProp(defaultValue: 10),
                    "limit": limitProp(),
                    "offset": offsetProp()
                ], required: ["latitude", "longitude"]),
                annotations: .init(readOnlyHint: true),
                outputSchema: searchResponseSchema
            ),
            Tool(
                name: "get_photos_by_date",
                description: "Find photos taken on a specific date or within a date range with application-level pagination metadata.",
                inputSchema: schema(properties: [
                    "date": dateProp("Specific date for photos on that day"),
                    "start_date": dateProp("Start of date range"),
                    "end_date": dateProp("End of date range"),
                    "limit": limitProp(),
                    "offset": offsetProp()
                ]),
                annotations: .init(readOnlyHint: true),
                outputSchema: searchResponseSchema
            ),
            Tool(
                name: "list_moments",
                description: "Return photo moments/collections grouped by time and location with application-level pagination metadata.",
                inputSchema: schema(properties: [
                    "limit": limitProp("Maximum moments to return"),
                    "offset": offsetProp()
                ]),
                annotations: .init(readOnlyHint: true),
                outputSchema: momentListSchema
            )
        ]
    }
}
