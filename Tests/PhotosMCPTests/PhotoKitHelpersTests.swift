import MCP
import Testing
@testable import PhotosMCP

struct PhotoKitHelpersTests {

    @Test("encodeToJSON produces valid JSON")
    func encodeToJSON() throws {
        let response = PhotoKitHelpers.SearchResponse(
            assets: [],
            total: 0,
            limit: 50,
            offset: 0
        )
        let json = try PhotoKitHelpers.encodeToJSON(response)
        #expect(json.contains("\"assets\""))
        #expect(json.contains("\"total\""))
        #expect(json.contains("\"limit\""))
        #expect(json.contains("\"offset\""))
        #expect(json.contains("\"total\" : 0"))
    }

    @Test("encodeToJSON with asset metadata")
    func encodeToJSONWithAssets() throws {
        let asset = PhotoKitHelpers.AssetMetadata(
            identifier: "test-id",
            creationDate: "2024-01-01T00:00:00Z",
            modificationDate: nil,
            mediaType: "photo",
            mediaSubtypes: ["none"],
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: nil,
            isFavorite: false,
            isHidden: false,
            location: .init(latitude: 40.0, longitude: -74.0),
            resourceFileSizes: nil
        )
        let response = PhotoKitHelpers.SearchResponse(
            assets: [asset],
            total: 1,
            limit: 50,
            offset: 0
        )
        let json = try PhotoKitHelpers.encodeToJSON(response)
        #expect(json.contains("test-id"))
        #expect(json.contains("photo"))
        #expect(json.contains("1920"))
        #expect(json.contains("1080"))
    }

    @Test("structuredResult includes structured content and JSON text")
    func structuredResult() throws {
        let response = PhotoKitHelpers.LibraryStatsResponse(
            photos: 3,
            videos: 2,
            totalAssets: 5,
            albums: 1,
            dateRange: .init(earliest: "2024-01-01T00:00:00Z", latest: nil)
        )

        let result = try PhotoKitHelpers.structuredResult(response)
        #expect(result.isError == false)
        #expect(result.structuredContent != nil)
        #expect(result.content.count == 1)

        guard case .text(let text, _, _) = result.content[0] else {
            Issue.record("Expected text content")
            return
        }

        #expect(text.contains("\"total_assets\" : 5"))
        #expect(text.contains("\"date_range\""))

        guard case .object(let object)? = result.structuredContent else {
            Issue.record("Expected structured object")
            return
        }

        #expect(object["photos"] == .int(3))
        #expect(object["videos"] == .int(2))
        #expect(object["total_assets"] == .int(5))
    }

    @Test("structured response JSON preserves snake case fields")
    func structuredResponseJSONPreservesSnakeCase() throws {
        let album = PhotoKitHelpers.AlbumMetadata(
            identifier: "album-id",
            name: "Favorites",
            assetCount: 12,
            type: "album"
        )
        let albumJSON = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.AlbumListResponse(
            albums: [album],
            total: 1,
            limit: 50,
            offset: 0
        ))
        #expect(albumJSON.contains("\"asset_count\""))

        let moment = PhotoKitHelpers.MomentMetadata(
            identifier: "moment-id",
            title: nil,
            startDate: "2024-01-01T00:00:00Z",
            endDate: nil,
            locationNames: ["Denver"],
            assetCount: 2
        )
        let momentJSON = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.MomentListResponse(
            moments: [moment],
            total: 1,
            limit: 50,
            offset: 0
        ))
        #expect(momentJSON.contains("\"start_date\""))
        #expect(momentJSON.contains("\"location_names\""))

        let placeJSON = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.PlaceSearchResponse(
            place: .init(name: "Denver", latitude: 39.7392, longitude: -104.9903, radiusKm: 25),
            assets: [],
            total: 0,
            limit: 50,
            offset: 0
        ))
        #expect(placeJSON.contains("\"radius_km\""))
        #expect(placeJSON.hasPrefix("{"))
    }
}
