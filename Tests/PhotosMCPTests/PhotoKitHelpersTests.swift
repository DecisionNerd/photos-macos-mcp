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
            offset: 0,
            nextOffset: nil
        )
        let json = try PhotoKitHelpers.encodeToJSON(response)
        #expect(json.contains("\"assets\""))
        #expect(json.contains("\"total\""))
        #expect(json.contains("\"limit\""))
        #expect(json.contains("\"offset\""))
        #expect(json.contains("\"next_offset\" : null"))
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
            offset: 0,
            nextOffset: nil
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
            offset: 0,
            nextOffset: 50
        ))
        #expect(albumJSON.contains("\"asset_count\""))
        #expect(albumJSON.contains("\"next_offset\" : 50"))

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
            offset: 0,
            nextOffset: nil
        ))
        #expect(momentJSON.contains("\"start_date\""))
        #expect(momentJSON.contains("\"location_names\""))
        #expect(momentJSON.contains("\"next_offset\" : null"))

        let placeJSON = try PhotoKitHelpers.encodeToJSON(PhotoKitHelpers.PlaceSearchResponse(
            place: .init(name: "Denver", latitude: 39.7392, longitude: -104.9903, radiusKm: 25),
            assets: [],
            total: 0,
            limit: 50,
            offset: 0,
            nextOffset: nil
        ))
        #expect(placeJSON.contains("\"radius_km\""))
        #expect(placeJSON.contains("\"next_offset\" : null"))
        #expect(placeJSON.hasPrefix("{"))
    }

    @Test("pagination helper returns continuation offsets")
    func paginationHelperReturnsContinuationOffsets() {
        let items = Array(0..<10)

        let first = PhotoKitHelpers.page(items: items, limit: 3, offset: 0)
        #expect(first.items == [0, 1, 2])
        #expect(first.nextOffset == 3)

        let middle = PhotoKitHelpers.page(items: items, limit: 3, offset: 3)
        #expect(middle.items == [3, 4, 5])
        #expect(middle.nextOffset == 6)

        let final = PhotoKitHelpers.page(items: items, limit: 3, offset: 9)
        #expect(final.items == [9])
        #expect(final.nextOffset == nil)

        let exactBoundary = PhotoKitHelpers.page(items: items, limit: 5, offset: 5)
        #expect(exactBoundary.items == [5, 6, 7, 8, 9])
        #expect(exactBoundary.nextOffset == nil)

        let outOfRange = PhotoKitHelpers.page(items: items, limit: 3, offset: 20)
        #expect(outOfRange.items.isEmpty)
        #expect(outOfRange.nextOffset == nil)
    }

    @Test("structured paginated result includes next offset in both payloads")
    func structuredPaginatedResultIncludesNextOffsetInBothPayloads() throws {
        let response = PhotoKitHelpers.SearchResponse(
            assets: [],
            total: 100,
            limit: 50,
            offset: 0,
            nextOffset: 50
        )

        let result = try PhotoKitHelpers.structuredResult(response)

        guard case .text(let text, _, _) = result.content[0] else {
            Issue.record("Expected text content")
            return
        }
        #expect(text.contains("\"next_offset\" : 50"))

        guard case .object(let object)? = result.structuredContent else {
            Issue.record("Expected structured object")
            return
        }
        #expect(object["next_offset"] == .int(50))
    }
}
