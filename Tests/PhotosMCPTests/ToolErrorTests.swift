import MCP
import Testing
@testable import PhotosMCP

struct ToolErrorTests {
    @Test("tool error result includes JSON text and metadata envelope")
    func toolErrorResultIncludesJSONTextAndMetadataEnvelope() {
        let result = ToolError.result(
            code: "not_found.asset",
            category: .notFound,
            message: "The requested Photos asset was not found.",
            retryable: false,
            remediation: "Verify asset_identifier came from a recent PhotosMCP result and retry."
        )

        #expect(result.isError == true)
        #expect(result.structuredContent == nil)

        guard case .text(let text, _, _)? = result.content.first else {
            Issue.record("Expected JSON text content")
            return
        }

        #expect(text.contains("\"code\" : \"not_found.asset\""))
        #expect(text.contains("\"category\" : \"not_found\""))
        #expect(text.contains("\"message\" : \"The requested Photos asset was not found.\""))
        #expect(text.contains("\"retryable\" : false"))
        #expect(text.contains("\"remediation\""))

        guard case .object(let meta)? = result._meta?[ToolError.metaKey] else {
            Issue.record("Expected photos_error metadata envelope")
            return
        }

        #expect(meta["code"] == .string("not_found.asset"))
        #expect(meta["category"] == .string("not_found"))
        #expect(meta["retryable"] == .bool(false))
    }

    @Test("domain error helpers use stable categories and privacy safe messages")
    func domainErrorHelpersUseStableCategoriesAndPrivacySafeMessages() {
        let errors = [
            ToolError.permissionDenied(),
            ToolError.assetNotFound(),
            ToolError.albumNotFound(),
            ToolError.unsupportedMediaType(expected: "photo"),
            ToolError.geocodingFailed(),
            ToolError.exportFailed(kind: "thumbnail"),
            ToolError.internalFailure()
        ]

        let expectedCategories = [
            "permission",
            "not_found",
            "not_found",
            "unsupported_media_type",
            "external_service",
            "export",
            "internal"
        ]

        for (result, category) in zip(errors, expectedCategories) {
            guard case .object(let meta)? = result._meta?[ToolError.metaKey],
                  case .text(let text, _, _)? = result.content.first else {
                Issue.record("Expected typed error envelope")
                continue
            }
            #expect(meta["category"] == .string(category))
            #expect(!text.contains("asset/"))
            #expect(!text.contains("/tmp/"))
            #expect(!text.contains("latitude"))
            #expect(!text.contains("longitude"))
        }
    }

    @Test("unknown tool names are protocol errors")
    func unknownToolNamesAreProtocolErrors() {
        #expect(PhotosServer.isKnownTool("search_photos"))
        #expect(!PhotosServer.isKnownTool("not_a_tool"))

        do {
            try PhotosServer.validateKnownToolName("not_a_tool")
            Issue.record("Expected unknown tool to throw")
        } catch let error as MCPError {
            #expect(error == .invalidParams("Unknown tool: not_a_tool"))
        } catch {
            Issue.record("Expected MCPError.invalidParams")
        }
    }
}
