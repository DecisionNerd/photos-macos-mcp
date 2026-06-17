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
        #expect(properties["keywordInfo"] != nil)
    }
}
