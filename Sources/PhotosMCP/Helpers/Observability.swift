import Foundation
import MCP

actor Observability {
    private(set) var minimumLevel: LogLevel = .notice

    func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }

    func isEnabled(_ level: LogLevel) -> Bool {
        Self.priority(level) >= Self.priority(minimumLevel)
    }

    func eventPayload(
        event: String,
        status: String? = nil,
        toolName: String? = nil,
        resourceKind: ResourceKind? = nil,
        durationMs: Int? = nil,
        error: ToolErrorEnvelope? = nil,
        authorizationStatus: String? = nil
    ) -> Value {
        Self.eventPayload(
            event: event,
            status: status,
            toolName: toolName,
            resourceKind: resourceKind,
            durationMs: durationMs,
            errorCode: error?.code,
            errorCategory: error?.category.rawValue,
            authorizationStatus: authorizationStatus
        )
    }

    static func eventPayload(
        event: String,
        status: String? = nil,
        toolName: String? = nil,
        resourceKind: ResourceKind? = nil,
        durationMs: Int? = nil,
        errorCode: String? = nil,
        errorCategory: String? = nil,
        authorizationStatus: String? = nil
    ) -> Value {
        var fields: [String: Value] = ["event": .string(event)]
        if let status {
            fields["status"] = .string(status)
        }
        if let toolName {
            fields["tool"] = .string(toolName)
        }
        if let resourceKind {
            fields["resource_kind"] = .string(resourceKind.rawValue)
        }
        if let durationMs {
            fields["duration_ms"] = .int(durationMs)
        }
        if let errorCode {
            fields["error_code"] = .string(errorCode)
        }
        if let errorCategory {
            fields["error_category"] = .string(errorCategory)
        }
        if let authorizationStatus {
            fields["authorization_status"] = .string(authorizationStatus)
        }
        return .object(fields)
    }

    static func priority(_ level: LogLevel) -> Int {
        switch level {
        case .debug: return 0
        case .info: return 1
        case .notice: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        case .alert: return 6
        case .emergency: return 7
        }
    }

    static func durationMs(since start: ContinuousClock.Instant) -> Int {
        let elapsed = start.duration(to: .now)
        return Int(elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
    }

    static func containsSensitiveDiagnostics(_ value: Value) -> Bool {
        let text = String(describing: value)
        let forbidden = [
            "photos://",
            "asset/",
            "/tmp/",
            "latitude",
            "longitude",
            "Denver",
            "2024-",
            "classification"
        ]
        return forbidden.contains { text.contains($0) }
    }

    enum ResourceKind: String, Sendable {
        case assetMetadata = "asset_metadata"
        case boundedExportThumbnail = "bounded_export_thumbnail"
        case boundedExportFull = "bounded_export_full"
        case unknown
    }

    static func resourceKind(from uri: String) -> ResourceKind {
        guard let components = URLComponents(string: uri), components.scheme == "photos" else {
            return .unknown
        }

        switch components.host {
        case "asset":
            return .assetMetadata
        case "export":
            let variant = components.queryItems?.first { $0.name == "variant" }?.value
            if variant == "thumbnail" {
                return .boundedExportThumbnail
            }
            if variant == "full" {
                return .boundedExportFull
            }
            return .unknown
        default:
            return .unknown
        }
    }
}
