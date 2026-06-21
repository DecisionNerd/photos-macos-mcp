import MCP
import Testing
@testable import PhotosMCP

struct ToolArgumentValidationTests {

    @Test("unknown parameters fail before tool work")
    func unknownParametersFailBeforeToolWork() async throws {
        let result = try await LibraryTools.getLibraryStats(arguments: ["unexpected": .string("value")])

        #expect(result.isError == true)
        #expect(text(from: result).contains("Unknown argument 'unexpected'"))
    }

    @Test("invalid pagination values fail before PhotoKit work")
    func invalidPaginationValuesFailBeforePhotoKitWork() async throws {
        let zeroLimit = try await SearchTools.searchPhotos(arguments: ["limit": .int(0)])
        let negativeOffset = try await AlbumTools.getAlbumContents(arguments: [
            "album_identifier": .string("album"),
            "offset": .int(-1)
        ])

        #expect(zeroLimit.isError == true)
        #expect(text(from: zeroLimit).contains("limit must be at least 1"))
        #expect(negativeOffset.isError == true)
        #expect(text(from: negativeOffset).contains("offset must be at least 0"))
    }

    @Test("invalid enum and date values fail before PhotoKit work")
    func invalidEnumAndDateValuesFailBeforePhotoKitWork() async throws {
        let badMediaType = try await SearchTools.searchPhotos(arguments: ["media_type": .string("gif")])
        let badDate = try await SearchTools.getPhotosByDate(arguments: ["date": .string("not-a-date")])

        #expect(badMediaType.isError == true)
        #expect(text(from: badMediaType).contains("media_type must be one of"))
        #expect(badDate.isError == true)
        #expect(text(from: badDate).contains("date must be yyyy-MM-dd or an ISO 8601 datetime"))
    }

    @Test("invalid image export values fail before PhotoKit work")
    func invalidImageExportValuesFailBeforePhotoKitWork() async throws {
        let badQuality = try await ImageTools.getPhotoThumbnail(arguments: [
            "asset_identifier": .string("asset"),
            "quality": .double(1.5)
        ])
        let badDimension = try await ImageTools.getPhotoFull(arguments: [
            "asset_identifier": .string("asset"),
            "max_dimension": .int(0)
        ])

        #expect(badQuality.isError == true)
        #expect(text(from: badQuality).contains("quality must be at most 1.0"))
        #expect(badDimension.isError == true)
        #expect(text(from: badDimension).contains("max_dimension must be at least 1"))
    }

    @Test("invalid coordinates radius and classification limits fail before work")
    func invalidCoordinatesRadiusAndClassificationLimitsFailBeforeWork() async throws {
        let badLatitude = try await SearchTools.getPhotosByLocation(arguments: [
            "latitude": .double(91),
            "longitude": .double(0)
        ])
        let badRadius = try await SearchTools.getPhotosByPlace(arguments: [
            "place": .string("Paris"),
            "radius_km": .double(0)
        ])
        let badMaxResults = try await AssetTools.getAssetClassifications(arguments: [
            "asset_identifier": .string("asset"),
            "max_results": .int(31)
        ])

        #expect(badLatitude.isError == true)
        #expect(text(from: badLatitude).contains("latitude must be at most 90.0"))
        #expect(badRadius.isError == true)
        #expect(text(from: badRadius).contains("radius_km must be greater than 0.0"))
        #expect(badMaxResults.isError == true)
        #expect(text(from: badMaxResults).contains("max_results must be at most 30"))
    }

    private func text(from result: CallTool.Result) -> String {
        guard case .text(let text, _, _)? = result.content.first else {
            return ""
        }
        return text
    }
}
