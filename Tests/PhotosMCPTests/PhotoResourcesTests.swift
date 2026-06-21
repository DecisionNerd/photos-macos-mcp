import MCP
import Testing
@testable import PhotosMCP

struct PhotoResourcesTests {
    @Test("asset URI round trips local identifiers with slashes")
    func assetURIRoundTripsLocalIdentifiersWithSlashes() throws {
        let identifier = "A1B2C3/L0/001"
        let uri = PhotoResources.assetURI(for: identifier)

        #expect(uri == "photos://asset/A1B2C3%2FL0%2F001")
        #expect(try PhotoResources.parse(uri) == .asset(assetIdentifier: identifier))
    }

    @Test("export URI round trips thumbnail and full requests")
    func exportURIRoundTripsThumbnailAndFullRequests() throws {
        let identifier = "asset/with/slash"

        let thumbnailURI = PhotoResources.exportURI(
            for: identifier,
            variant: .thumbnail,
            maxDimension: 512,
            quality: 0.8
        )
        #expect(try PhotoResources.parse(thumbnailURI) == .export(.init(
            assetIdentifier: identifier,
            variant: .thumbnail,
            maxDimension: 512,
            quality: 0.8
        )))

        let fullURI = PhotoResources.exportURI(
            for: identifier,
            variant: .full,
            maxDimension: 2048,
            quality: 0.75
        )
        #expect(try PhotoResources.parse(fullURI) == .export(.init(
            assetIdentifier: identifier,
            variant: .full,
            maxDimension: 2048,
            quality: 0.75
        )))
    }

    @Test("export quality defaults when omitted")
    func exportQualityDefaultsWhenOmitted() throws {
        #expect(try PhotoResources.parse("photos://export/asset-id?variant=thumbnail&max_dimension=256") == .export(.init(
            assetIdentifier: "asset-id",
            variant: .thumbnail,
            maxDimension: 256,
            quality: 0.8
        )))
    }

    @Test("invalid resource URIs fail before PhotoKit work")
    func invalidResourceURIsFailBeforePhotoKitWork() {
        let invalidURIs = [
            "file://asset/A1B2",
            "photos://album/A1B2",
            "photos://asset/",
            "photos://asset/A1B2?unexpected=true",
            "photos://asset/A1B2%ZZ",
            "photos://asset/..%2Fsecret",
            "photos://export/A1B2?variant=thumbnail",
            "photos://export/A1B2?variant=thumbnail&max_dimension=0",
            "photos://export/A1B2?variant=full&max_dimension=2048&quality=1.5",
            "photos://export/A1B2?variant=full&max_dimension=2048&extra=true",
            "photos://export/A1B2?variant=poster&max_dimension=2048",
            "photos://export/A1B2?variant=full&max_dimension=2048#fragment"
        ]

        for uri in invalidURIs {
            #expect(throws: PhotoResources.ResourceError.self, "Expected invalid URI to fail: \(uri)") {
                try PhotoResources.parse(uri)
            }
        }
    }

    @Test("resource templates describe metadata and bounded export resources")
    func resourceTemplatesDescribeMetadataAndBoundedExportResources() throws {
        let templates = PhotoResources.templates

        #expect(templates.count == 2)
        #expect(templates.map(\.name) == ["photos_asset_metadata", "photos_image_export"])
        #expect(templates[0].uriTemplate == "photos://asset/{asset_identifier}")
        #expect(templates[0].mimeType == PhotoResources.assetMimeType)
        #expect(templates[0].annotations?.audience == [.assistant])
        #expect(templates[1].uriTemplate == "photos://export/{asset_identifier}{?variant,max_dimension,quality}")
        #expect(templates[1].mimeType == PhotoResources.exportMimeType)
        #expect(templates[1].annotations?.audience == [.user, .assistant])
    }

    @Test("resources list does not enumerate Photos library")
    func resourcesListDoesNotEnumeratePhotosLibrary() {
        let result = ListResources.Result(resources: PhotoResources.listedResources, nextCursor: nil)

        #expect(result.resources.isEmpty)
        #expect(result.nextCursor == nil)
    }

    @Test("resource templates result contains resource templates")
    func resourceTemplatesResultContainsResourceTemplates() throws {
        let result = ListResourceTemplates.Result(templates: PhotoResources.templates, nextCursor: nil)

        #expect(result.templates.map(\.name) == ["photos_asset_metadata", "photos_image_export"])
        #expect(result.nextCursor == nil)
    }

    @Test("asset and export resource links encode as tool content")
    func assetAndExportResourceLinksEncodeAsToolContent() throws {
        let asset = PhotoKitHelpers.AssetMetadata(
            identifier: "asset/one",
            creationDate: nil,
            modificationDate: nil,
            mediaType: "photo",
            mediaSubtypes: ["none"],
            pixelWidth: 100,
            pixelHeight: 100,
            duration: nil,
            isFavorite: false,
            isHidden: false,
            location: nil,
            resourceFileSizes: nil
        )

        let assetLink = PhotoResources.assetResourceLink(for: asset)
        let exportLink = PhotoResources.exportResourceLink(
            for: asset.identifier,
            variant: .thumbnail,
            maxDimension: 512,
            quality: 0.8
        )

        guard case .resourceLink(let assetURI, _, _, _, let assetMimeType, _) = assetLink,
              case .resourceLink(let exportURI, _, _, _, let exportMimeType, _) = exportLink else {
            Issue.record("Expected resource links")
            return
        }

        #expect(assetURI == "photos://asset/asset%2Fone")
        #expect(assetMimeType == PhotoResources.assetMimeType)
        #expect(exportURI.contains("photos://export/asset%2Fone"))
        #expect(exportMimeType == PhotoResources.exportMimeType)
    }
}
