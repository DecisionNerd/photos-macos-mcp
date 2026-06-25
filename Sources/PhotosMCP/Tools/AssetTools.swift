import Foundation
import MCP
import Photos

enum AssetTools {

    static func getAssetDetails(arguments: [String: Value]?) async throws -> CallTool.Result {
        let assetId: String
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: ["asset_identifier"])
            assetId = try ToolArgumentValidation.requiredString(arguments, name: "asset_identifier")
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return ToolError.assetNotFound()
            }

            let meta = PhotoKitHelpers.metadata(from: asset)

            // Resource file sizes: PhotoKit does not expose a public fileSize API.
            // PHAssetResource's fileSize is private KVO; we omit it for API stability.
            let metaWithSizes = PhotoKitHelpers.AssetDetailsResponse(
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

            return try PhotoKitHelpers.structuredResult(
                metaWithSizes,
                resourceLinks: [PhotoResources.assetResourceLink(for: meta)]
            )
        }.value
    }

    static func getAssetClassifications(arguments: [String: Value]?) async throws -> CallTool.Result {
        let assetId: String
        let maxResults: Int
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: ["asset_identifier", "max_results"])
            assetId = try ToolArgumentValidation.requiredString(arguments, name: "asset_identifier")
            maxResults = try ToolArgumentValidation.int(arguments, name: "max_results", default: 10, min: 1, max: 30)
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return ToolError.assetNotFound()
            }

            guard asset.mediaType == .image else {
                return ToolError.unsupportedMediaType(expected: "photo")
            }

            let classifications = await ContentClassifier.classifications(
                for: asset,
                maxResults: maxResults
            )
            let response = PhotoKitHelpers.AssetClassificationsResponse(
                assetIdentifier: assetId,
                classifications: classifications
            )

            do {
                return try PhotoKitHelpers.structuredResult(response)
            } catch {
                return ToolError.internalFailure(code: "internal.classification_encoding_failed")
            }
        }.value
    }
}
