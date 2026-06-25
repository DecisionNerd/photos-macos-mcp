import MCP
import Photos

enum DiagnosticsTools {
    struct DiagnosticsResponse: Codable, Sendable {
        let server: ServerInfo
        let capabilities: CapabilitiesInfo
        let photos: PhotosInfo
        let inventory: InventoryInfo
        let logging: LoggingInfo
        let remediation: [String]

        struct ServerInfo: Codable, Sendable {
            let name: String
            let version: String
            let sdkSpecSupport: String

            enum CodingKeys: String, CodingKey {
                case name
                case version
                case sdkSpecSupport = "sdk_spec_support"
            }
        }

        struct CapabilitiesInfo: Codable, Sendable {
            let tools: Bool
            let resources: Bool
            let logging: Bool
        }

        struct PhotosInfo: Codable, Sendable {
            let requiredAccessLevel: String
            let authorizationStatus: String

            enum CodingKeys: String, CodingKey {
                case requiredAccessLevel = "required_access_level"
                case authorizationStatus = "authorization_status"
            }
        }

        struct InventoryInfo: Codable, Sendable {
            let toolCount: Int
            let resourceTemplateCount: Int
            let listedResourceCount: Int

            enum CodingKeys: String, CodingKey {
                case toolCount = "tool_count"
                case resourceTemplateCount = "resource_template_count"
                case listedResourceCount = "listed_resource_count"
            }
        }

        struct LoggingInfo: Codable, Sendable {
            let mcpLogging: Bool
            let defaultLevel: String
            let wrapperLogHint: String

            enum CodingKeys: String, CodingKey {
                case mcpLogging = "mcp_logging"
                case defaultLevel = "default_level"
                case wrapperLogHint = "wrapper_log_hint"
            }
        }
    }

    static func diagnose(arguments: [String: Value]?) throws -> CallTool.Result {
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: [])
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }
        return try PhotoKitHelpers.structuredResult(response())
    }

    static func response(
        authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: PhotosAccess.requiredAccessLevel)
    ) -> DiagnosticsResponse {
        DiagnosticsResponse(
            server: .init(
                name: ServerMetadata.name,
                version: ServerMetadata.version,
                sdkSpecSupport: ServerMetadata.sdkSpecSupport
            ),
            capabilities: .init(
                tools: ServerMetadata.capabilities.tools != nil,
                resources: ServerMetadata.capabilities.resources != nil,
                logging: ServerMetadata.capabilities.logging != nil
            ),
            photos: .init(
                requiredAccessLevel: accessLevelString(PhotosAccess.requiredAccessLevel),
                authorizationStatus: statusString(authorizationStatus)
            ),
            inventory: .init(
                toolCount: ToolDefinitions.all.count,
                resourceTemplateCount: PhotoResources.templates.count,
                listedResourceCount: PhotoResources.listedResources.count
            ),
            logging: .init(
                mcpLogging: true,
                defaultLevel: "notice",
                wrapperLogHint: "${TMPDIR:-/tmp}/photos-mcp.log when using scripts/run-photos-mcp.sh"
            ),
            remediation: remediation(for: authorizationStatus)
        )
    }

    static func statusString(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .limited: return "limited"
        case .notDetermined: return "not_determined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }

    static func accessLevelString(_ accessLevel: PHAccessLevel) -> String {
        switch accessLevel {
        case .addOnly: return "add_only"
        case .readWrite: return "read_write"
        @unknown default: return "unknown"
        }
    }

    private static func remediation(for status: PHAuthorizationStatus) -> [String] {
        switch status {
        case .authorized, .limited:
            return [
                "Use get_library_stats to verify the visible Photos scope.",
                "Use search_photos with a small limit to confirm tool access."
            ]
        case .notDetermined:
            return [
                "Call a Photos-reading tool when ready to trigger the macOS Photos permission prompt.",
                "Grant Photos access to the MCP client process in System Settings if prompted."
            ]
        case .denied, .restricted:
            return [
                "Grant Photos access in System Settings > Privacy & Security > Photos.",
                "Restart the MCP client after changing Photos permissions."
            ]
        @unknown default:
            return [
                "Check macOS Photos privacy settings and restart the MCP client."
            ]
        }
    }
}
