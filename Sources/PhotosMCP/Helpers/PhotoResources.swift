import Foundation
import MCP
import Photos

enum PhotoResources {
    static let assetMimeType = "application/json"
    static let exportMimeType = "image/jpeg"

    enum Parsed: Equatable, Sendable {
        case asset(assetIdentifier: String)
        case export(ExportRequest)
    }

    struct ExportRequest: Equatable, Sendable {
        enum Variant: String, Sendable {
            case thumbnail
            case full
        }

        let assetIdentifier: String
        let variant: Variant
        let maxDimension: Int
        let quality: Double
    }

    enum ResourceError: Error, LocalizedError, Equatable {
        case invalidURI(String)
        case assetNotFound
        case unsupportedMediaType

        var errorDescription: String? {
            switch self {
            case .invalidURI(let message):
                return message
            case .assetNotFound:
                return "Resource not found"
            case .unsupportedMediaType:
                return "Export resources are only available for photo assets"
            }
        }
    }

    static var templates: [Resource.Template] {
        [
            Resource.Template(
                uriTemplate: "photos://asset/{asset_identifier}",
                name: "photos_asset_metadata",
                title: "Photos Asset Metadata",
                description: "JSON metadata for a Photos asset by local identifier.",
                mimeType: assetMimeType,
                annotations: .init(audience: [.assistant], priority: 0.8)
            ),
            Resource.Template(
                uriTemplate: "photos://export/{asset_identifier}{?variant,max_dimension,quality}",
                name: "photos_image_export",
                title: "Photos Bounded Image Export",
                description: "Bounded JPEG export for a Photos image asset. Requires variant and max_dimension.",
                mimeType: exportMimeType,
                annotations: .init(audience: [.user, .assistant], priority: 0.7)
            )
        ]
    }

    static var listedResources: [Resource] {
        []
    }

    static func assetURI(for assetIdentifier: String) -> String {
        "photos://asset/\(encodePathComponent(assetIdentifier))"
    }

    static func exportURI(
        for assetIdentifier: String,
        variant: ExportRequest.Variant,
        maxDimension: Int,
        quality: Double
    ) -> String {
        let roundedQuality = (quality * 1000).rounded() / 1000
        let qualityText = String(roundedQuality)
        return "photos://export/\(encodePathComponent(assetIdentifier))?variant=\(variant.rawValue)&max_dimension=\(maxDimension)&quality=\(qualityText)"
    }

    static func assetResourceLink(
        for asset: PhotoKitHelpers.AssetMetadata
    ) -> Tool.Content {
        .resourceLink(
            uri: assetURI(for: asset.identifier),
            name: "photos_asset_metadata",
            title: "Photos asset metadata",
            description: "Metadata resource for Photos asset \(asset.identifier)",
            mimeType: assetMimeType,
            annotations: .init(audience: [.assistant], priority: 0.7)
        )
    }

    static func exportResourceLink(
        for assetIdentifier: String,
        variant: ExportRequest.Variant,
        maxDimension: Int,
        quality: Double
    ) -> Tool.Content {
        .resourceLink(
            uri: exportURI(
                for: assetIdentifier,
                variant: variant,
                maxDimension: maxDimension,
                quality: quality
            ),
            name: "photos_image_export",
            title: variant == .thumbnail ? "Photos thumbnail export" : "Photos bounded full export",
            description: "Bounded JPEG export for a Photos image asset.",
            mimeType: exportMimeType,
            annotations: .init(audience: [.user, .assistant], priority: 0.8)
        )
    }

    static func parse(_ uri: String) throws -> Parsed {
        guard hasValidPercentEscapes(uri) else {
            throw ResourceError.invalidURI("Resource URI is not valid percent-encoding")
        }
        guard let components = URLComponents(string: uri),
              components.scheme == "photos" else {
            throw ResourceError.invalidURI("Resource URI must use the photos scheme")
        }

        guard components.fragment == nil else {
            throw ResourceError.invalidURI("Resource URI fragments are not supported")
        }

        guard let host = components.host, host == "asset" || host == "export" else {
            throw ResourceError.invalidURI("Resource URI host must be asset or export")
        }

        let identifier = try decodeIdentifier(from: components.percentEncodedPath)
        switch host {
        case "asset":
            guard components.queryItems?.isEmpty ?? true else {
                throw ResourceError.invalidURI("Asset resources do not accept query parameters")
            }
            return .asset(assetIdentifier: identifier)
        case "export":
            return .export(try parseExport(identifier: identifier, components: components))
        default:
            throw ResourceError.invalidURI("Unsupported Photos resource")
        }
    }

    static func read(uri: String) async throws -> ReadResource.Result {
        switch try parse(uri) {
        case .asset(let assetIdentifier):
            return try await readAsset(uri: uri, assetIdentifier: assetIdentifier)
        case .export(let request):
            return try await readExport(uri: uri, request: request)
        }
    }

    private static func readAsset(uri: String, assetIdentifier: String) async throws -> ReadResource.Result {
        try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = fetchResult.firstObject else {
                throw ResourceError.assetNotFound
            }

            let meta = PhotoKitHelpers.metadata(from: asset)
            let response = PhotoKitHelpers.AssetDetailsResponse(
                identifier: meta.identifier,
                creationDate: meta.creationDate,
                modificationDate: meta.modificationDate,
                mediaType: meta.mediaType,
                mediaSubtypes: meta.mediaSubtypes,
                pixelWidth: meta.pixelWidth,
                pixelHeight: meta.pixelHeight,
                duration: meta.duration,
                isFavorite: meta.isFavorite,
                isHidden: meta.isHidden,
                location: meta.location,
                resourceFileSizes: nil
            )
            let json = try PhotoKitHelpers.encodeToJSON(response)
            return ReadResource.Result(
                contents: [.text(json, uri: uri, mimeType: assetMimeType)]
            )
        }.value
    }

    private static func readExport(uri: String, request: ExportRequest) async throws -> ReadResource.Result {
        try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [request.assetIdentifier], options: nil)
            guard let asset = fetchResult.firstObject else {
                throw ResourceError.assetNotFound
            }
            guard asset.mediaType == .image else {
                throw ResourceError.unsupportedMediaType
            }

            let quality = CGFloat(request.quality)
            let data: Data
            switch request.variant {
            case .thumbnail:
                data = try await ImageExport.thumbnail(
                    asset: asset,
                    maxDimension: request.maxDimension,
                    quality: quality
                )
            case .full:
                data = try await ImageExport.fullImage(
                    asset: asset,
                    maxDimension: request.maxDimension,
                    quality: quality
                )
            }

            return ReadResource.Result(
                contents: [.binary(data, uri: uri, mimeType: exportMimeType)]
            )
        }.value
    }

    private static func parseExport(
        identifier: String,
        components: URLComponents
    ) throws -> ExportRequest {
        let allowedKeys = Set(["variant", "max_dimension", "quality"])
        let queryItems = components.queryItems ?? []
        let grouped = Dictionary(grouping: queryItems, by: \.name)

        for key in grouped.keys where !allowedKeys.contains(key) {
            throw ResourceError.invalidURI("Unknown export query parameter '\(key)'")
        }
        for (key, items) in grouped where items.count > 1 {
            throw ResourceError.invalidURI("Duplicate export query parameter '\(key)'")
        }

        guard let variantText = grouped["variant"]?.first?.value,
              let variant = ExportRequest.Variant(rawValue: variantText) else {
            throw ResourceError.invalidURI("Export resources require variant thumbnail or full")
        }

        guard let maxDimensionText = grouped["max_dimension"]?.first?.value,
              let maxDimension = Int(maxDimensionText),
              maxDimension >= 1 else {
            throw ResourceError.invalidURI("Export resources require max_dimension of at least 1")
        }

        let quality: Double
        if let qualityText = grouped["quality"]?.first?.value {
            guard let parsedQuality = Double(qualityText),
                  parsedQuality.isFinite,
                  parsedQuality >= 0,
                  parsedQuality <= 1 else {
                throw ResourceError.invalidURI("Export quality must be between 0 and 1")
            }
            quality = parsedQuality
        } else {
            quality = 0.8
        }

        return ExportRequest(
            assetIdentifier: identifier,
            variant: variant,
            maxDimension: maxDimension,
            quality: quality
        )
    }

    private static func decodeIdentifier(from percentEncodedPath: String) throws -> String {
        guard percentEncodedPath.hasPrefix("/") else {
            throw ResourceError.invalidURI("Resource URI path must contain an asset identifier")
        }
        let encodedIdentifier = String(percentEncodedPath.dropFirst())
        guard !encodedIdentifier.isEmpty else {
            throw ResourceError.invalidURI("Resource URI path must contain an asset identifier")
        }
        guard !encodedIdentifier.contains("/") else {
            throw ResourceError.invalidURI("Asset identifier must be percent-encoded as one path segment")
        }
        guard hasValidPercentEscapes(encodedIdentifier) else {
            throw ResourceError.invalidURI("Asset identifier is not valid percent-encoding")
        }
        guard let identifier = encodedIdentifier.removingPercentEncoding,
              !identifier.isEmpty else {
            throw ResourceError.invalidURI("Asset identifier is not valid percent-encoding")
        }
        guard !identifier.contains("..") else {
            throw ResourceError.invalidURI("Asset identifier must not contain path traversal markers")
        }
        return identifier
    }

    private static func encodePathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private static func hasValidPercentEscapes(_ value: String) -> Bool {
        let scalars = Array(value.unicodeScalars)
        var index = 0
        while index < scalars.count {
            if scalars[index] == "%" {
                guard index + 2 < scalars.count,
                      isHexDigit(scalars[index + 1]),
                      isHexDigit(scalars[index + 2]) else {
                    return false
                }
                index += 3
            } else {
                index += 1
            }
        }
        return true
    }

    private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...70, 97...102:
            return true
        default:
            return false
        }
    }
}
