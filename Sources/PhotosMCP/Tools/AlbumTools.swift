import Foundation
import MCP
import Photos

enum AlbumTools {

    static func getAlbumContents(arguments: [String: Value]?) async throws -> CallTool.Result {
        let albumId: String
        let limit: Int
        let offset: Int
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: ["album_identifier", "limit", "offset"])
            albumId = try ToolArgumentValidation.requiredString(arguments, name: "album_identifier")
            limit = try ToolArgumentValidation.int(arguments, name: "limit", default: 50, min: 1, max: 200)
            offset = try ToolArgumentValidation.int(arguments, name: "offset", default: 0, min: 0)
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return try await Task.detached(priority: .userInitiated) {
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
            guard let collection = collections.firstObject else {
                return .init(content: [PhotoKitHelpers.textContent("Error: Album not found with identifier \(albumId)")], isError: true)
            }

            let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            var assets: [PhotoKitHelpers.AssetMetadata] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(PhotoKitHelpers.metadata(from: asset))
            }

            let total = assets.count
            let page = PhotoKitHelpers.page(items: assets, limit: limit, offset: offset)
            return try PhotoKitHelpers.structuredResult(PhotoKitHelpers.SearchResponse(
                assets: page.items,
                total: total,
                limit: limit,
                offset: offset,
                nextOffset: page.nextOffset
            ), resourceLinks: page.items.map(PhotoResources.assetResourceLink))
        }.value
    }
}
