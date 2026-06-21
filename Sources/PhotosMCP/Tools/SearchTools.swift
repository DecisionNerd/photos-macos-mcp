import Foundation
import MCP
import Photos
import MapKit

enum SearchTools {

    static func searchPhotos(arguments: [String: Value]?) async throws -> CallTool.Result {
        let limit: Int
        let offset: Int
        let startDateStr: String
        let endDateStr: String
        let mediaTypeStr: String
        let isFavorite: Bool
        let keyword: String
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: [
                "start_date", "end_date", "media_type", "is_favorite", "keyword", "limit", "offset"
            ])
            limit = try ToolArgumentValidation.int(arguments, name: "limit", default: 50, min: 1, max: 200)
            offset = try ToolArgumentValidation.int(arguments, name: "offset", default: 0, min: 0)
            startDateStr = try ToolArgumentValidation.optionalDateString(arguments, name: "start_date")
            endDateStr = try ToolArgumentValidation.optionalDateString(arguments, name: "end_date")
            mediaTypeStr = try ToolArgumentValidation.optionalEnum(
                arguments,
                name: "media_type",
                default: "any",
                allowed: ["photo", "video", "live_photo", "any"]
            )
            isFavorite = try ToolArgumentValidation.bool(arguments, name: "is_favorite", default: false)
            keyword = try ToolArgumentValidation.optionalString(arguments, name: "keyword") ?? ""
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        let options = PHFetchOptions()
        var predicates: [NSPredicate] = []

        if !startDateStr.isEmpty, let start = DateParsing.parse(startDateStr) {
            predicates.append(NSPredicate(format: "creationDate >= %@", start as NSDate))
        }
        if !endDateStr.isEmpty, let end = DateParsing.parseEndOfDay(endDateStr) ?? DateParsing.parse(endDateStr) {
            predicates.append(NSPredicate(format: "creationDate <= %@", end as NSDate))
        }
        if isFavorite {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }
        if !predicates.isEmpty {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult: PHFetchResult<PHAsset>
            switch mediaTypeStr {
            case "photo":
                fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            case "video":
                fetchResult = PHAsset.fetchAssets(with: .video, options: options)
            case "live_photo":
                fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            default:
                fetchResult = PHAsset.fetchAssets(with: options)
            }

            var assets: [PhotoKitHelpers.AssetMetadata] = []
            var assetRefs: [PHAsset] = []
            let filterLivePhoto = (mediaTypeStr == "live_photo")
            fetchResult.enumerateObjects { asset, _, _ in
                if filterLivePhoto && !asset.mediaSubtypes.contains(.photoLive) {
                    return
                }
                assets.append(PhotoKitHelpers.metadata(from: asset))
                assetRefs.append(asset)
            }

            var filtered = assets
            var keywordInfo: PhotoKitHelpers.KeywordSearchInfo?
            if !keyword.isEmpty {
                let searchResult = await filterAssetsByKeywordWithFallback(assetRefs: assetRefs, keyword: keyword)
                let matchingIndices = searchResult.indices
                filtered = matchingIndices.map { assets[$0] }
                keywordInfo = searchResult.info
            }

            let total = filtered.count
            let page = PhotoKitHelpers.page(items: filtered, limit: limit, offset: offset)
            return try PhotoKitHelpers.structuredResult(PhotoKitHelpers.SearchResponseWithKeywordInfo(
                assets: page.items,
                total: total,
                limit: limit,
                offset: offset,
                nextOffset: page.nextOffset,
                keywordInfo: keywordInfo
            ), resourceLinks: page.items.map(PhotoResources.assetResourceLink))
        }.value
    }

    static func getPhotosByLocation(arguments: [String: Value]?) async throws -> CallTool.Result {
        let lat: Double
        let lon: Double
        let radiusKm: Double
        let limit: Int
        let offset: Int
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: [
                "latitude", "longitude", "radius_km", "limit", "offset"
            ])
            lat = try ToolArgumentValidation.requiredDouble(arguments, name: "latitude", min: -90, max: 90)
            lon = try ToolArgumentValidation.requiredDouble(arguments, name: "longitude", min: -180, max: 180)
            radiusKm = try ToolArgumentValidation.double(arguments, name: "radius_km", default: 10, min: 0, exclusiveMin: true)
            limit = try ToolArgumentValidation.int(arguments, name: "limit", default: 50, min: 1, max: 200)
            offset = try ToolArgumentValidation.int(arguments, name: "offset", default: 0, min: 0)
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return try await Task.detached(priority: .userInitiated) {
            let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
            var results: [PhotoKitHelpers.AssetMetadata] = []
            allPhotos.enumerateObjects { asset, _, _ in
                guard let loc = asset.location else { return }
                let distance = GeoUtils.haversineKm(lat1: lat, lon1: lon, lat2: loc.coordinate.latitude, lon2: loc.coordinate.longitude)
                if distance <= radiusKm {
                    results.append(PhotoKitHelpers.metadata(from: asset))
                }
            }

            let total = results.count
            let page = PhotoKitHelpers.page(items: results, limit: limit, offset: offset)
            return try PhotoKitHelpers.structuredResult(PhotoKitHelpers.SearchResponse(
                assets: page.items,
                total: total,
                limit: limit,
                offset: offset,
                nextOffset: page.nextOffset
            ), resourceLinks: page.items.map(PhotoResources.assetResourceLink))
        }.value
    }

    static func getPhotosByDate(arguments: [String: Value]?) async throws -> CallTool.Result {
        let dateStr: String
        let startDateStr: String
        let endDateStr: String
        let limit: Int
        let offset: Int
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: [
                "date", "start_date", "end_date", "limit", "offset"
            ])
            dateStr = try ToolArgumentValidation.optionalDateString(arguments, name: "date")
            startDateStr = try ToolArgumentValidation.optionalDateString(arguments, name: "start_date")
            endDateStr = try ToolArgumentValidation.optionalDateString(arguments, name: "end_date")
            limit = try ToolArgumentValidation.int(arguments, name: "limit", default: 50, min: 1, max: 200)
            offset = try ToolArgumentValidation.int(arguments, name: "offset", default: 0, min: 0)
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        var startDate: Date?
        var endDate: Date?

        if !dateStr.isEmpty {
            if let d = DateParsing.parse(dateStr) {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "UTC") ?? .current
                startDate = cal.startOfDay(for: d)
                if let start = startDate {
                    endDate = cal.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-0.001)
                }
            }
        } else {
            if !startDateStr.isEmpty { startDate = DateParsing.parse(startDateStr) }
            if !endDateStr.isEmpty { endDate = DateParsing.parseEndOfDay(endDateStr) ?? DateParsing.parse(endDateStr) }
        }

        var predicates: [NSPredicate] = []
        if let s = startDate { predicates.append(NSPredicate(format: "creationDate >= %@", s as NSDate)) }
        if let e = endDate { predicates.append(NSPredicate(format: "creationDate <= %@", e as NSDate)) }

        let options = PHFetchOptions()
        if !predicates.isEmpty {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        return try await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(with: options)
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

    /// Search photos by place name (city, country, etc.). Geocodes the name to coordinates, then finds photos nearby.
    static func getPhotosByPlace(arguments: [String: Value]?) async throws -> CallTool.Result {
        let placeName: String
        let radiusKm: Double
        let limit: Int
        let offset: Int
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: [
                "place", "radius_km", "limit", "offset"
            ])
            placeName = try ToolArgumentValidation.requiredString(arguments, name: "place", displayName: "place name")
            radiusKm = try ToolArgumentValidation.double(arguments, name: "radius_km", default: 25, min: 0, exclusiveMin: true)
            limit = try ToolArgumentValidation.int(arguments, name: "limit", default: 50, min: 1, max: 200)
            offset = try ToolArgumentValidation.int(arguments, name: "offset", default: 0, min: 0)
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        let coordinate: (latitude: Double, longitude: Double)?
        do {
            guard let request = MKGeocodingRequest(addressString: placeName) else {
                return .init(content: [PhotoKitHelpers.textContent("Error: Could not create geocoding request for '\(placeName)'")], isError: true)
            }
            coordinate = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(latitude: Double, longitude: Double)?, Error>) in
                request.getMapItems { items, error in
                    if let error = error { cont.resume(throwing: error); return }
                    guard let location = items?.first?.location else {
                        cont.resume(returning: nil)
                        return
                    }
                    cont.resume(returning: (location.coordinate.latitude, location.coordinate.longitude))
                }
            }
        } catch {
            return .init(content: [PhotoKitHelpers.textContent("Error: Could not find '\(placeName)': \(error.localizedDescription)")], isError: true)
        }
        guard let coordinate else {
            return .init(content: [PhotoKitHelpers.textContent("Error: No coordinates for '\(placeName)'")], isError: true)
        }

        let lat = coordinate.latitude
        let lon = coordinate.longitude

        return try await Task.detached(priority: .userInitiated) {
            let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
            var results: [PhotoKitHelpers.AssetMetadata] = []
            allPhotos.enumerateObjects { asset, _, _ in
                guard let assetLoc = asset.location else { return }
                let distance = GeoUtils.haversineKm(lat1: lat, lon1: lon, lat2: assetLoc.coordinate.latitude, lon2: assetLoc.coordinate.longitude)
                if distance <= radiusKm {
                    results.append(PhotoKitHelpers.metadata(from: asset))
                }
            }

            let total = results.count
            let page = PhotoKitHelpers.page(items: results, limit: limit, offset: offset)
            return try PhotoKitHelpers.structuredResult(PhotoKitHelpers.PlaceSearchResponse(
                place: .init(name: placeName, latitude: lat, longitude: lon, radiusKm: radiusKm),
                assets: page.items,
                total: total,
                limit: limit,
                offset: offset,
                nextOffset: page.nextOffset
            ), resourceLinks: page.items.map(PhotoResources.assetResourceLink))
        }.value
    }
}

private struct KeywordFilterResult {
    let indices: [Int]
    let info: PhotoKitHelpers.KeywordSearchInfo
}

private func filterAssetsByKeywordWithFallback(assetRefs: [PHAsset], keyword: String) async -> KeywordFilterResult {
    let analyzedAssets = min(assetRefs.count, ContentClassifier.maxAssetsToAnalyze)
    let primaryThreshold = ContentClassifier.defaultConfidenceThreshold
    let fallbackThreshold: Float = 0.2
    let fallbackKeywords = ContentClassifier.fallbackKeywords(for: keyword)

    let primaryMatches = await filterAssetsByKeyword(
        assetRefs: assetRefs,
        keyword: keyword,
        confidenceThreshold: primaryThreshold
    )
    if !primaryMatches.isEmpty {
        return KeywordFilterResult(
            indices: primaryMatches,
            info: PhotoKitHelpers.KeywordSearchInfo(
                requestedKeyword: keyword,
                matchedKeyword: keyword,
                usedFallback: false,
                fallbackKeywords: fallbackKeywords,
                confidenceThreshold: primaryThreshold,
                analyzedAssets: analyzedAssets,
                maxAnalyzedAssets: ContentClassifier.maxAssetsToAnalyze
            )
        )
    }

    for fallbackKeyword in fallbackKeywords {
        let fallbackMatches = await filterAssetsByKeyword(
            assetRefs: assetRefs,
            keyword: fallbackKeyword,
            confidenceThreshold: fallbackThreshold
        )
        if !fallbackMatches.isEmpty {
            return KeywordFilterResult(
                indices: fallbackMatches,
                info: PhotoKitHelpers.KeywordSearchInfo(
                    requestedKeyword: keyword,
                    matchedKeyword: fallbackKeyword,
                    usedFallback: true,
                    fallbackKeywords: fallbackKeywords,
                    confidenceThreshold: fallbackThreshold,
                    analyzedAssets: analyzedAssets,
                    maxAnalyzedAssets: ContentClassifier.maxAssetsToAnalyze
                )
            )
        }
    }

    return KeywordFilterResult(
        indices: [],
        info: PhotoKitHelpers.KeywordSearchInfo(
            requestedKeyword: keyword,
            matchedKeyword: nil,
            usedFallback: false,
            fallbackKeywords: fallbackKeywords,
            confidenceThreshold: primaryThreshold,
            analyzedAssets: analyzedAssets,
            maxAnalyzedAssets: ContentClassifier.maxAssetsToAnalyze
        )
    )
}

private func filterAssetsByKeyword(
    assetRefs: [PHAsset],
    keyword: String,
    confidenceThreshold: Float
) async -> [Int] {
    let maxAnalyze = min(assetRefs.count, ContentClassifier.maxAssetsToAnalyze)
    var matching: [Int] = []
    for i in 0..<maxAnalyze {
        let matches = await ContentClassifier.assetMatchesKeyword(
            asset: assetRefs[i],
            keyword: keyword,
            confidenceThreshold: confidenceThreshold
        )
        if matches { matching.append(i) }
    }
    return matching
}
