import Foundation
import MCP
import Photos

/// JSON-friendly representations of PhotoKit entities for MCP tool responses.
enum PhotoKitHelpers {

    // MARK: - Asset Metadata

    struct AssetMetadata: Codable, Sendable {
        let identifier: String
        let creationDate: String?
        let modificationDate: String?
        let mediaType: String
        let mediaSubtypes: [String]
        let pixelWidth: Int
        let pixelHeight: Int
        let duration: Double?
        let isFavorite: Bool
        let isHidden: Bool
        let location: Location?
        let resourceFileSizes: [Int]?

        struct Location: Codable, Sendable {
            let latitude: Double
            let longitude: Double
        }
    }

    static func metadata(from asset: PHAsset) -> AssetMetadata {
        let location: AssetMetadata.Location?
        if let loc = asset.location {
            location = .init(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        } else {
            location = nil
        }

        var subtypes: [String] = []
        if asset.mediaSubtypes.contains(.photoPanorama) { subtypes.append("panorama") }
        if asset.mediaSubtypes.contains(.photoHDR) { subtypes.append("hdr") }
        if asset.mediaSubtypes.contains(.photoScreenshot) { subtypes.append("screenshot") }
        if asset.mediaSubtypes.contains(.photoLive) { subtypes.append("live") }
        if asset.mediaSubtypes.contains(.videoHighFrameRate) { subtypes.append("high_frame_rate") }
        if asset.mediaSubtypes.contains(.videoTimelapse) { subtypes.append("timelapse") }
        if asset.mediaSubtypes.contains(.videoStreamed) { subtypes.append("streamed") }
        if subtypes.isEmpty { subtypes.append("none") }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")

        return AssetMetadata(
            identifier: asset.localIdentifier,
            creationDate: asset.creationDate.map { formatter.string(from: $0) },
            modificationDate: asset.modificationDate.map { formatter.string(from: $0) },
            mediaType: mediaTypeString(asset.mediaType),
            mediaSubtypes: subtypes,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            duration: asset.mediaType == .video ? asset.duration : nil,
            isFavorite: asset.isFavorite,
            isHidden: asset.isHidden,
            location: location,
            resourceFileSizes: nil // Populated separately when available
        )
    }

    static func mediaTypeString(_ type: PHAssetMediaType) -> String {
        switch type {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "audio"
        default: return "unknown"
        }
    }

    // MARK: - Album Metadata

    struct AlbumMetadata: Codable, Sendable {
        let identifier: String
        let name: String
        let assetCount: Int
        let type: String // "album" | "smart_album" | "moment"

        enum CodingKeys: String, CodingKey {
            case identifier
            case name
            case assetCount = "asset_count"
            case type
        }
    }

    static func albumMetadata(from collection: PHCollection) -> AlbumMetadata? {
        guard let assetCollection = collection as? PHAssetCollection else { return nil }
        let count = PHAsset.fetchAssets(in: assetCollection, options: nil).count
        let type: String
        if assetCollection.assetCollectionSubtype == .smartAlbumUserLibrary ||
            assetCollection.assetCollectionSubtype.rawValue >= 200 {
            type = "smart_album"
        } else {
            type = "album"
        }
        return AlbumMetadata(
            identifier: assetCollection.localIdentifier,
            name: assetCollection.localizedTitle ?? "Unknown",
            assetCount: count,
            type: type
        )
    }

    // MARK: - Moment Metadata

    struct MomentMetadata: Codable, Sendable {
        let identifier: String
        let title: String?
        let startDate: String?
        let endDate: String?
        let locationNames: [String]
        let assetCount: Int

        enum CodingKeys: String, CodingKey {
            case identifier
            case title
            case startDate = "start_date"
            case endDate = "end_date"
            case locationNames = "location_names"
            case assetCount = "asset_count"
        }
    }

    static func momentMetadata(from moment: PHAssetCollection) -> MomentMetadata {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")

        let count = PHAsset.fetchAssets(in: moment, options: nil).count
        let locationNames = moment.localizedLocationNames

        return MomentMetadata(
            identifier: moment.localIdentifier,
            title: moment.localizedTitle,
            startDate: moment.startDate.map { formatter.string(from: $0) },
            endDate: moment.endDate.map { formatter.string(from: $0) },
            locationNames: locationNames,
            assetCount: count
        )
    }

    // MARK: - Search Response (shared by SearchTools, AlbumTools)

    struct Page<T: Sendable>: Sendable {
        let items: [T]
        let nextOffset: Int?
    }

    static func page<T: Sendable>(items: [T], limit: Int, offset: Int) -> Page<T> {
        let slice = Array(items.dropFirst(offset).prefix(limit))
        let nextOffset = offset + slice.count
        return Page(
            items: slice,
            nextOffset: nextOffset < items.count ? nextOffset : nil
        )
    }

    private static func encodeNextOffset<Key: CodingKey>(
        _ nextOffset: Int?,
        to container: inout KeyedEncodingContainer<Key>,
        forKey key: Key
    ) throws {
        if let nextOffset {
            try container.encode(nextOffset, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    struct SearchResponse: Codable, Sendable {
        let assets: [AssetMetadata]
        let total: Int
        let limit: Int
        let offset: Int
        let nextOffset: Int?

        enum CodingKeys: String, CodingKey {
            case assets
            case total
            case limit
            case offset
            case nextOffset = "next_offset"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(assets, forKey: .assets)
            try container.encode(total, forKey: .total)
            try container.encode(limit, forKey: .limit)
            try container.encode(offset, forKey: .offset)
            try PhotoKitHelpers.encodeNextOffset(nextOffset, to: &container, forKey: .nextOffset)
        }
    }

    struct AlbumListResponse: Codable, Sendable {
        let albums: [AlbumMetadata]
        let total: Int
        let limit: Int
        let offset: Int
        let nextOffset: Int?

        enum CodingKeys: String, CodingKey {
            case albums
            case total
            case limit
            case offset
            case nextOffset = "next_offset"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(albums, forKey: .albums)
            try container.encode(total, forKey: .total)
            try container.encode(limit, forKey: .limit)
            try container.encode(offset, forKey: .offset)
            try PhotoKitHelpers.encodeNextOffset(nextOffset, to: &container, forKey: .nextOffset)
        }
    }

    struct LibraryStatsResponse: Codable, Sendable {
        let photos: Int
        let videos: Int
        let totalAssets: Int
        let albums: Int
        let dateRange: DateRange

        enum CodingKeys: String, CodingKey {
            case photos
            case videos
            case totalAssets = "total_assets"
            case albums
            case dateRange = "date_range"
        }

        struct DateRange: Codable, Sendable {
            let earliest: String?
            let latest: String?
        }
    }

    struct MomentListResponse: Codable, Sendable {
        let moments: [MomentMetadata]
        let total: Int
        let limit: Int
        let offset: Int
        let nextOffset: Int?

        enum CodingKeys: String, CodingKey {
            case moments
            case total
            case limit
            case offset
            case nextOffset = "next_offset"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(moments, forKey: .moments)
            try container.encode(total, forKey: .total)
            try container.encode(limit, forKey: .limit)
            try container.encode(offset, forKey: .offset)
            try PhotoKitHelpers.encodeNextOffset(nextOffset, to: &container, forKey: .nextOffset)
        }
    }

    struct KeywordSearchInfo: Codable, Sendable {
        let requestedKeyword: String
        let matchedKeyword: String?
        let usedFallback: Bool
        let fallbackKeywords: [String]
        let confidenceThreshold: Float
        let analyzedAssets: Int
        let maxAnalyzedAssets: Int
    }

    struct SearchResponseWithKeywordInfo: Codable, Sendable {
        let assets: [AssetMetadata]
        let total: Int
        let limit: Int
        let offset: Int
        let nextOffset: Int?
        let keywordInfo: KeywordSearchInfo?

        enum CodingKeys: String, CodingKey {
            case assets
            case total
            case limit
            case offset
            case nextOffset = "next_offset"
            case keywordInfo
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(assets, forKey: .assets)
            try container.encode(total, forKey: .total)
            try container.encode(limit, forKey: .limit)
            try container.encode(offset, forKey: .offset)
            try PhotoKitHelpers.encodeNextOffset(nextOffset, to: &container, forKey: .nextOffset)
            if let keywordInfo {
                try container.encode(keywordInfo, forKey: .keywordInfo)
            } else {
                try container.encodeNil(forKey: .keywordInfo)
            }
        }
    }

    struct PlaceSearchResponse: Codable, Sendable {
        let place: PlaceInfo
        let assets: [AssetMetadata]
        let total: Int
        let limit: Int
        let offset: Int
        let nextOffset: Int?

        enum CodingKeys: String, CodingKey {
            case place
            case assets
            case total
            case limit
            case offset
            case nextOffset = "next_offset"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(place, forKey: .place)
            try container.encode(assets, forKey: .assets)
            try container.encode(total, forKey: .total)
            try container.encode(limit, forKey: .limit)
            try container.encode(offset, forKey: .offset)
            try PhotoKitHelpers.encodeNextOffset(nextOffset, to: &container, forKey: .nextOffset)
        }

        struct PlaceInfo: Codable, Sendable {
            let name: String
            let latitude: Double
            let longitude: Double
            let radiusKm: Double

            enum CodingKeys: String, CodingKey {
                case name
                case latitude
                case longitude
                case radiusKm = "radius_km"
            }
        }
    }

    struct AssetDetailsResponse: Codable, Sendable {
        let identifier: String
        let creationDate: String?
        let modificationDate: String?
        let mediaType: String
        let mediaSubtypes: [String]
        let pixelWidth: Int
        let pixelHeight: Int
        let duration: Double?
        let isFavorite: Bool
        let isHidden: Bool
        let location: AssetMetadata.Location?
        let resourceFileSizes: [Int]?
    }

    struct AssetClassificationsResponse: Codable, Sendable {
        let assetIdentifier: String
        let classifications: [ContentClassifier.Classification]
    }

    // MARK: - Encoding Helpers

    static func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "PhotoKitHelpers", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"])
        }
        return str
    }

    static func structuredResult<T: Codable>(_ value: T) throws -> CallTool.Result {
        let json = try encodeToJSON(value)
        return try CallTool.Result(
            content: [textContent(json)],
            structuredContent: value,
            isError: false
        )
    }

    static func structuredResult<T: Codable>(
        _ value: T,
        resourceLinks: [Tool.Content]
    ) throws -> CallTool.Result {
        let json = try encodeToJSON(value)
        return try CallTool.Result(
            content: [textContent(json)] + resourceLinks,
            structuredContent: value,
            isError: false
        )
    }

    static func textContent(_ text: String) -> Tool.Content {
        .text(text: text, annotations: nil, _meta: nil)
    }
}
