import Foundation
import MCP
import Photos

enum LibraryTools {

    static func listAlbums(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit: Int
        let offset: Int
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: ["limit", "offset"])
            limit = try ToolArgumentValidation.int(arguments, name: "limit", default: 50, min: 1, max: 200)
            offset = try ToolArgumentValidation.int(arguments, name: "offset", default: 0, min: 0)
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return try await Task.detached(priority: .userInitiated) {
            let topLevel = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

            var albums: [PhotoKitHelpers.AlbumMetadata] = []

            for i in 0..<smartAlbums.count {
                let col = smartAlbums.object(at: i)
                if let meta = PhotoKitHelpers.albumMetadata(from: col) {
                    albums.append(meta)
                }
            }

            for i in 0..<topLevel.count {
                let col = topLevel.object(at: i)
                if let assetCol = col as? PHAssetCollection, let meta = PhotoKitHelpers.albumMetadata(from: assetCol) {
                    albums.append(meta)
                } else if let folder = col as? PHCollectionList {
                    let sub = PHCollection.fetchCollections(in: folder, options: nil)
                    for j in 0..<sub.count {
                        let c = sub.object(at: j)
                        if let ac = c as? PHAssetCollection, let meta = PhotoKitHelpers.albumMetadata(from: ac) {
                            albums.append(meta)
                        }
                    }
                }
            }

            let total = albums.count
            let page = PhotoKitHelpers.page(items: albums, limit: limit, offset: offset)
            return try PhotoKitHelpers.structuredResult(PhotoKitHelpers.AlbumListResponse(
                albums: page.items,
                total: total,
                limit: limit,
                offset: offset,
                nextOffset: page.nextOffset
            ))
        }.value
    }

    static func getLibraryStats(arguments: [String: Value]?) async throws -> CallTool.Result {
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: [])
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return try await Task.detached(priority: .userInitiated) {
            let allPhotos = PHAsset.fetchAssets(with: nil)
            var photoCount = 0
            var videoCount = 0
            var earliest: Date?
            var latest: Date?

            allPhotos.enumerateObjects { asset, _, _ in
                switch asset.mediaType {
                case .image: photoCount += 1
                case .video: videoCount += 1
                default: break
                }
                if let d = asset.creationDate {
                    if let e = earliest {
                        if d < e { earliest = d }
                    } else {
                        earliest = d
                    }
                    if let l = latest {
                        if d > l { latest = d }
                    } else {
                        latest = d
                    }
                }
            }

            let topLevel = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            let albumCount = topLevel.count + smartAlbums.count

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(identifier: "UTC")

            return try PhotoKitHelpers.structuredResult(PhotoKitHelpers.LibraryStatsResponse(
                photos: photoCount,
                videos: videoCount,
                totalAssets: photoCount + videoCount,
                albums: albumCount,
                dateRange: .init(
                    earliest: earliest.map { formatter.string(from: $0) },
                    latest: latest.map { formatter.string(from: $0) }
                )
            ))
        }.value
    }

    static func listMoments(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit: Int
        let offset: Int
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: ["limit", "offset"])
            limit = try ToolArgumentValidation.int(arguments, name: "limit", default: 50, min: 1, max: 200)
            offset = try ToolArgumentValidation.int(arguments, name: "offset", default: 0, min: 0)
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return try await Task.detached(priority: .userInitiated) {
            // fetchMoments is unavailable on macOS - return empty with info
            var list: [PhotoKitHelpers.MomentMetadata] = []
            #if os(iOS)
            let moments = PHAssetCollection.fetchMoments(with: nil)
            moments.enumerateObjects { moment, _, _ in
                list.append(PhotoKitHelpers.momentMetadata(from: moment))
            }
            #endif

            let total = list.count
            let page = PhotoKitHelpers.page(items: list, limit: limit, offset: offset)
            return try PhotoKitHelpers.structuredResult(PhotoKitHelpers.MomentListResponse(
                moments: page.items,
                total: total,
                limit: limit,
                offset: offset,
                nextOffset: page.nextOffset
            ))
        }.value
    }
}
