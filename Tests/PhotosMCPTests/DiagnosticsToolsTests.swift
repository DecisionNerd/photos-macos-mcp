import MCP
import Photos
import Testing
@testable import PhotosMCP

struct DiagnosticsToolsTests {
    @Test("diagnostics response maps authorization state without prompting")
    func diagnosticsResponseMapsAuthorizationState() throws {
        let response = DiagnosticsTools.response(authorizationStatus: .denied)

        #expect(response.server.name == "PhotosMCP")
        #expect(response.capabilities.tools)
        #expect(response.capabilities.resources)
        #expect(response.capabilities.logging)
        #expect(response.photos.requiredAccessLevel == "read_write")
        #expect(response.photos.authorizationStatus == "denied")
        #expect(response.inventory.resourceTemplateCount == PhotoResources.templates.count)
        #expect(response.logging.defaultLevel == "notice")
        #expect(response.remediation.contains { $0.contains("System Settings") })

        let json = try PhotoKitHelpers.encodeToJSON(response)
        #expect(json.contains("\"required_access_level\""))
        #expect(json.contains("\"authorization_status\" : \"denied\""))
        #expect(json.contains("\"resource_template_count\""))
        #expect(json.contains("\"wrapper_log_hint\""))
    }

    @Test("diagnostics derives access level string from PhotoKit access level")
    func diagnosticsDerivesAccessLevelStringFromPhotoKitAccessLevel() {
        #expect(DiagnosticsTools.accessLevelString(.readWrite) == "read_write")
        #expect(DiagnosticsTools.accessLevelString(.addOnly) == "add_only")
    }

    @Test("diagnostics tool returns structured content and JSON text")
    func diagnosticsToolReturnsStructuredContentAndJSONText() throws {
        let result = try DiagnosticsTools.diagnose(arguments: nil)

        #expect(result.isError == false)
        #expect(result.structuredContent != nil)
        guard case .text(let text, _, _)? = result.content.first else {
            Issue.record("Expected JSON text")
            return
        }

        #expect(text.contains("\"sdk_spec_support\""))
        #expect(text.contains("\"mcp_logging\" : true"))

        guard case .object(let object)? = result.structuredContent,
              case .object(let server)? = object["server"],
              case .object(let capabilities)? = object["capabilities"] else {
            Issue.record("Expected structured diagnostics object")
            return
        }

        #expect(server["name"] == .string("PhotosMCP"))
        #expect(capabilities["logging"] == .bool(true))
    }

    @Test("diagnostics rejects unknown arguments")
    func diagnosticsRejectsUnknownArguments() throws {
        let result = try DiagnosticsTools.diagnose(arguments: ["asset_identifier": .string("asset/abc")])

        #expect(result.isError == true)
        guard case .object(let meta)? = result._meta?[ToolError.metaKey] else {
            Issue.record("Expected structured validation error")
            return
        }
        #expect(meta["category"] == .string("validation"))
    }
}
