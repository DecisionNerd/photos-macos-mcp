import MCP
import Testing
@testable import PhotosMCP

struct ToolDefinitionsTests {

    @Test("structured tools declare output schemas")
    func structuredToolsDeclareOutputSchemas() {
        let toolsByName = Dictionary(uniqueKeysWithValues: ToolDefinitions.all.map { ($0.name, $0) })
        let structuredToolNames = [
            "list_albums",
            "get_library_stats",
            "search_photos",
            "get_album_contents",
            "get_asset_details",
            "get_asset_classifications",
            "get_photos_by_place",
            "get_photos_by_location",
            "get_photos_by_date",
            "list_moments"
        ]

        for name in structuredToolNames {
            #expect(toolsByName[name]?.outputSchema != nil, "Expected \(name) to declare outputSchema")
        }
    }

    @Test("image export tools do not declare output schemas")
    func imageToolsDoNotDeclareOutputSchemas() {
        let toolsByName = Dictionary(uniqueKeysWithValues: ToolDefinitions.all.map { ($0.name, $0) })

        #expect(toolsByName["get_photo_thumbnail"]?.outputSchema == nil)
        #expect(toolsByName["get_photo_full"]?.outputSchema == nil)
    }

    @Test("image export descriptions document hybrid transfer contract")
    func imageExportDescriptionsDocumentHybridTransferContract() {
        let toolsByName = Dictionary(uniqueKeysWithValues: ToolDefinitions.all.map { ($0.name, $0) })
        let thumbnailDescription = toolsByName["get_photo_thumbnail"]?.description ?? ""
        let fullDescription = toolsByName["get_photo_full"]?.description ?? ""

        #expect(thumbnailDescription.contains("temp-file text"))
        #expect(thumbnailDescription.contains("inline JPEG image content"))
        #expect(thumbnailDescription.contains("resource_link"))
        #expect(fullDescription.contains("temp-file text"))
        #expect(fullDescription.contains("never inline image content"))
        #expect(fullDescription.contains("resource_link"))
        #expect(fullDescription.contains("max_dimension"))
    }

    @Test("search output schema describes expected top-level fields")
    func searchOutputSchemaDescribesTopLevelFields() {
        let searchTool = ToolDefinitions.all.first { $0.name == "search_photos" }

        guard case .object(let schema)? = searchTool?.outputSchema,
              case .object(let properties)? = schema["properties"] else {
            Issue.record("Expected search_photos outputSchema object with properties")
            return
        }

        #expect(properties["assets"] != nil)
        #expect(properties["total"] != nil)
        #expect(properties["limit"] != nil)
        #expect(properties["offset"] != nil)
        #expect(properties["next_offset"] != nil)
        #expect(properties["keywordInfo"] != nil)
    }

    @Test("paginated output schemas include nullable next offset")
    func paginatedOutputSchemasIncludeNullableNextOffset() {
        let toolNames = [
            "list_albums",
            "search_photos",
            "get_album_contents",
            "get_photos_by_place",
            "get_photos_by_location",
            "get_photos_by_date",
            "list_moments"
        ]

        for name in toolNames {
            let tool = ToolDefinitions.all.first { $0.name == name }
            guard case .object(let schema)? = tool?.outputSchema,
                  case .object(let properties)? = schema["properties"],
                  case .array(let required)? = schema["required"],
                  case .object(let nextOffset)? = properties["next_offset"],
                  case .array(let types)? = nextOffset["type"] else {
                Issue.record("Expected \(name) outputSchema to include nullable next_offset")
                continue
            }

            #expect(required.contains(.string("next_offset")), "Expected \(name) to require next_offset")
            #expect(Set(types) == Set([.string("integer"), .string("null")]), "Expected \(name) next_offset to be integer or null")
        }
    }

    @Test("all tool input schemas reject additional properties")
    func allInputSchemasRejectAdditionalProperties() {
        for tool in ToolDefinitions.all {
            let schema = objectSchema(for: tool)
            #expect(schema["type"] == .string("object"), "Expected \(tool.name) inputSchema to be an object")
            #expect(schema["additionalProperties"] == .bool(false), "Expected \(tool.name) to reject unknown arguments")
        }
    }

    @Test("no argument tools use explicit empty object schemas")
    func noArgumentToolsUseExplicitEmptyObjectSchemas() {
        let tool = ToolDefinitions.all.first { $0.name == "get_library_stats" }

        let schema = objectSchema(for: tool)
        guard case .object(let properties)? = schema["properties"] else {
            Issue.record("Expected get_library_stats properties object")
            return
        }

        #expect(properties.isEmpty)
        #expect(schema["additionalProperties"] == .bool(false))
    }

    @Test("pagination schemas include defaults and bounds")
    func paginationSchemasIncludeDefaultsAndBounds() {
        let toolNames = [
            "list_albums",
            "search_photos",
            "get_album_contents",
            "get_photos_by_place",
            "get_photos_by_location",
            "get_photos_by_date",
            "list_moments"
        ]

        for name in toolNames {
            let properties = inputProperties(for: name)
            expectIntegerProperty(properties["limit"], defaultValue: 50, minimum: 1, maximum: 200)
            expectIntegerProperty(properties["offset"], defaultValue: 0, minimum: 0, maximum: nil)
        }
    }

    @Test("media type schema is a strict enum with default")
    func mediaTypeSchemaIsStrictEnumWithDefault() {
        let properties = inputProperties(for: "search_photos")
        guard case .object(let mediaType)? = properties["media_type"],
              case .array(let enumValues)? = mediaType["enum"] else {
            Issue.record("Expected media_type enum")
            return
        }

        #expect(mediaType["default"] == .string("any"))
        #expect(Set(enumValues) == Set([.string("photo"), .string("video"), .string("live_photo"), .string("any")]))
    }

    @Test("image schemas include quality and dimension constraints")
    func imageSchemasIncludeQualityAndDimensionConstraints() {
        let thumbnail = inputProperties(for: "get_photo_thumbnail")
        let full = inputProperties(for: "get_photo_full")

        expectNumberProperty(thumbnail["quality"], defaultValue: 0.8, minimum: 0.0, maximum: 1.0)
        expectIntegerProperty(thumbnail["max_dimension"], defaultValue: 512, minimum: 1, maximum: nil)
        expectNumberProperty(full["quality"], defaultValue: 0.8, minimum: 0.0, maximum: 1.0)
        expectIntegerProperty(full["max_dimension"], defaultValue: nil, minimum: 1, maximum: nil)
    }

    @Test("location schemas include coordinate and radius constraints")
    func locationSchemasIncludeCoordinateAndRadiusConstraints() {
        let properties = inputProperties(for: "get_photos_by_location")

        expectNumberProperty(properties["latitude"], defaultValue: nil, minimum: -90.0, maximum: 90.0)
        expectNumberProperty(properties["longitude"], defaultValue: nil, minimum: -180.0, maximum: 180.0)

        guard case .object(let radius)? = properties["radius_km"] else {
            Issue.record("Expected radius_km schema")
            return
        }
        #expect(radius["default"] == .double(10))
        #expect(radius["exclusiveMinimum"] == .double(0))
    }

    @Test("date schemas document accepted formats")
    func dateSchemasDocumentAcceptedFormats() {
        let properties = inputProperties(for: "get_photos_by_date")

        for field in ["date", "start_date", "end_date"] {
            guard case .object(let schema)? = properties[field],
                  case .string(let description)? = schema["description"] else {
                Issue.record("Expected \(field) description")
                return
            }
            #expect(description.contains("yyyy-MM-dd"))
            #expect(description.contains("ISO 8601"))
        }
    }

    private func inputProperties(for toolName: String) -> [String: Value] {
        let tool = ToolDefinitions.all.first { $0.name == toolName }
        let schema = objectSchema(for: tool)
        guard case .object(let properties)? = schema["properties"] else {
            Issue.record("Expected \(toolName) inputSchema properties")
            return [:]
        }
        return properties
    }

    private func objectSchema(for tool: Tool?) -> [String: Value] {
        guard case .object(let schema)? = tool?.inputSchema else {
            Issue.record("Expected inputSchema object")
            return [:]
        }
        return schema
    }

    private func expectIntegerProperty(
        _ value: Value?,
        defaultValue: Int?,
        minimum: Int?,
        maximum: Int?
    ) {
        guard case .object(let schema)? = value else {
            Issue.record("Expected integer property")
            return
        }
        #expect(schema["type"] == .string("integer"))
        if let defaultValue {
            #expect(schema["default"] == .int(defaultValue))
        } else {
            #expect(schema["default"] == nil)
        }
        if let minimum {
            #expect(schema["minimum"] == .int(minimum))
        }
        if let maximum {
            #expect(schema["maximum"] == .int(maximum))
        } else {
            #expect(schema["maximum"] == nil)
        }
    }

    private func expectNumberProperty(
        _ value: Value?,
        defaultValue: Double?,
        minimum: Double?,
        maximum: Double?
    ) {
        guard case .object(let schema)? = value else {
            Issue.record("Expected number property")
            return
        }
        #expect(schema["type"] == .string("number"))
        if let defaultValue {
            #expect(schema["default"] == .double(defaultValue))
        } else {
            #expect(schema["default"] == nil)
        }
        if let minimum {
            #expect(schema["minimum"] == .double(minimum))
        }
        if let maximum {
            #expect(schema["maximum"] == .double(maximum))
        } else {
            #expect(schema["maximum"] == nil)
        }
    }
}
