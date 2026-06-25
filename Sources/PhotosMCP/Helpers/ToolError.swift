import Foundation
import MCP

enum ToolErrorCategory: String, Codable, Sendable {
    case validation
    case permission
    case notFound = "not_found"
    case unsupportedMediaType = "unsupported_media_type"
    case externalService = "external_service"
    case export
    case photokit
    case `internal`
}

struct ToolErrorEnvelope: Codable, Equatable, Sendable {
    let code: String
    let category: ToolErrorCategory
    let message: String
    let retryable: Bool
    let remediation: String
}

enum ToolError {
    static let metaKey = "photos_error"

    static func result(
        code: String,
        category: ToolErrorCategory,
        message: String,
        retryable: Bool,
        remediation: String
    ) -> CallTool.Result {
        result(.init(
            code: code,
            category: category,
            message: message,
            retryable: retryable,
            remediation: remediation
        ))
    }

    static func result(_ envelope: ToolErrorEnvelope) -> CallTool.Result {
        let json = (try? PhotoKitHelpers.encodeToJSON(envelope)) ?? fallbackJSON(for: envelope)
        let metaValue = (try? Value(envelope)) ?? .object([
            "code": .string(envelope.code),
            "category": .string(envelope.category.rawValue),
            "message": .string(envelope.message),
            "retryable": .bool(envelope.retryable),
            "remediation": .string(envelope.remediation)
        ])

        return .init(
            content: [PhotoKitHelpers.textContent(json)],
            isError: true,
            _meta: Metadata(additionalFields: [metaKey: metaValue])
        )
    }

    static func validation(
        code: String,
        message: String,
        remediation: String = "Adjust the tool arguments to match the input schema and retry."
    ) -> CallTool.Result {
        result(
            code: code,
            category: .validation,
            message: message,
            retryable: true,
            remediation: remediation
        )
    }

    static func permissionDenied() -> CallTool.Result {
        result(
            code: "permission.photos_access_denied",
            category: .permission,
            message: "Photos library access is not available.",
            retryable: true,
            remediation: "Grant Photos access in System Settings, then retry the same tool call."
        )
    }

    static func assetNotFound() -> CallTool.Result {
        result(
            code: "not_found.asset",
            category: .notFound,
            message: "The requested Photos asset was not found.",
            retryable: false,
            remediation: "Verify asset_identifier came from a recent PhotosMCP result and retry."
        )
    }

    static func albumNotFound() -> CallTool.Result {
        result(
            code: "not_found.album",
            category: .notFound,
            message: "The requested Photos album was not found.",
            retryable: false,
            remediation: "Verify album_identifier came from list_albums and retry."
        )
    }

    static func unsupportedMediaType(expected: String) -> CallTool.Result {
        result(
            code: "unsupported_media_type.photo_required",
            category: .unsupportedMediaType,
            message: "The requested asset is not a \(expected).",
            retryable: false,
            remediation: "Use a Photos asset whose media_type is \(expected), then retry."
        )
    }

    static func geocodingRequestFailed() -> CallTool.Result {
        result(
            code: "external_service.geocoding_request_failed",
            category: .externalService,
            message: "The place search request could not be created.",
            retryable: false,
            remediation: "Provide a non-empty place name that can be geocoded."
        )
    }

    static func geocodingFailed() -> CallTool.Result {
        result(
            code: "external_service.geocoding_failed",
            category: .externalService,
            message: "The place could not be geocoded.",
            retryable: true,
            remediation: "Retry with a more specific place name, such as city and country."
        )
    }

    static func geocodingNoCoordinates() -> CallTool.Result {
        result(
            code: "external_service.geocoding_no_coordinates",
            category: .externalService,
            message: "The geocoding result did not include coordinates.",
            retryable: true,
            remediation: "Retry with a more specific place name."
        )
    }

    static func exportFailed(kind: String) -> CallTool.Result {
        result(
            code: "export.\(kind)_failed",
            category: .export,
            message: "The requested image export failed.",
            retryable: true,
            remediation: "Retry with a smaller max_dimension or lower quality."
        )
    }

    static func internalFailure(code: String = "internal.encoding_failed") -> CallTool.Result {
        result(
            code: code,
            category: .internal,
            message: "PhotosMCP could not complete the request.",
            retryable: true,
            remediation: "Retry the request; if it continues to fail, report the tool name and error code."
        )
    }

    private static func fallbackJSON(for envelope: ToolErrorEnvelope) -> String {
        """
        {"code":"\(escape(envelope.code))","category":"\(escape(envelope.category.rawValue))","message":"\(escape(envelope.message))","retryable":\(envelope.retryable),"remediation":"\(escape(envelope.remediation))"}
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
