import MCP
import Testing
@testable import PhotosMCP

struct ObservabilityTests {
    @Test("server capabilities declare logging")
    func serverCapabilitiesDeclareLogging() {
        #expect(ServerMetadata.capabilities.logging != nil)
        #expect(ServerMetadata.capabilities.tools != nil)
        #expect(ServerMetadata.capabilities.resources != nil)
    }

    @Test("log level gating respects minimum level")
    func logLevelGatingRespectsMinimumLevel() async {
        let observability = Observability()

        #expect(await observability.isEnabled(.notice))
        #expect(await observability.isEnabled(.warning))
        #expect(!(await observability.isEnabled(.info)))

        await observability.setMinimumLevel(.debug)
        #expect(await observability.isEnabled(.debug))
        #expect(await observability.isEnabled(.info))

        await observability.setMinimumLevel(.error)
        #expect(!(await observability.isEnabled(.warning)))
        #expect(await observability.isEnabled(.critical))
    }

    @Test("event payload contains safe categorical fields")
    func eventPayloadContainsSafeCategoricalFields() {
        let payload = Observability.eventPayload(
            event: "tool.failed",
            status: "error",
            toolName: "get_asset_details",
            resourceKind: .assetMetadata,
            durationMs: 12,
            errorCode: "not_found.asset",
            errorCategory: "not_found",
            authorizationStatus: "denied"
        )

        guard case .object(let object) = payload else {
            Issue.record("Expected object payload")
            return
        }

        #expect(object["event"] == .string("tool.failed"))
        #expect(object["tool"] == .string("get_asset_details"))
        #expect(object["resource_kind"] == .string("asset_metadata"))
        #expect(object["duration_ms"] == .int(12))
        #expect(object["error_code"] == .string("not_found.asset"))
        #expect(object["error_category"] == .string("not_found"))
        #expect(object["authorization_status"] == .string("denied"))
        #expect(!Observability.containsSensitiveDiagnostics(payload))
    }

    @Test("resource kind categorizes URIs without preserving identifiers")
    func resourceKindCategorizesURIsWithoutPreservingIdentifiers() {
        #expect(Observability.resourceKind(from: "photos://asset/asset%2Fabc") == .assetMetadata)
        #expect(Observability.resourceKind(from: "photos://export/asset%2Fabc?variant=thumbnail&max_dimension=512&quality=0.8") == .boundedExportThumbnail)
        #expect(Observability.resourceKind(from: "photos://export/asset%2Fabc?variant=full&max_dimension=2048&quality=0.8") == .boundedExportFull)
        #expect(Observability.resourceKind(from: "file:///tmp/photo.jpg") == .unknown)
    }

    @Test("redaction helper detects representative sensitive values")
    func redactionHelperDetectsRepresentativeSensitiveValues() {
        let sensitive = Value.object([
            "event": .string("resource.read_completed"),
            "uri": .string("photos://asset/asset%2Fabc"),
            "path": .string("/tmp/PhotosMCP/photo.jpg"),
            "latitude": .double(39.7)
        ])
        let safe = Observability.eventPayload(
            event: "resource.read_completed",
            status: "ok",
            resourceKind: .boundedExportThumbnail,
            durationMs: 5
        )

        #expect(Observability.containsSensitiveDiagnostics(sensitive))
        #expect(!Observability.containsSensitiveDiagnostics(safe))
    }
}
