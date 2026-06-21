import MCP
import Testing
@testable import PhotosMCP

struct ImageResponsePolicyTests {
    @Test("thumbnail response includes text inline image and resource link under limit")
    func thumbnailResponseIncludesInlineImageUnderLimit() {
        let content = ImageResponsePolicy.thumbnailContent(
            message: "Thumbnail saved. To view: `open /tmp/thumb.jpg`",
            imageBase64: "jpeg-base64",
            imageByteCount: ImageResponsePolicy.inlineThumbnailMaxBytes,
            assetIdentifier: "asset/one",
            maxDimension: 512,
            quality: 0.8
        )

        #expect(content.count == 3)
        guard case .text(let text, _, _) = content[0],
              case .image(let data, let mimeType, _, _) = content[1],
              case .resourceLink(let uri, _, _, _, let resourceMimeType, _) = content[2] else {
            Issue.record("Expected text, inline image, and resource link")
            return
        }

        #expect(text.contains("open /tmp/thumb.jpg"))
        #expect(data == "jpeg-base64")
        #expect(mimeType == PhotoResources.exportMimeType)
        #expect(uri == "photos://export/asset%2Fone?variant=thumbnail&max_dimension=512&quality=0.8")
        #expect(resourceMimeType == PhotoResources.exportMimeType)
    }

    @Test("thumbnail response omits inline image over limit")
    func thumbnailResponseOmitsInlineImageOverLimit() {
        let content = ImageResponsePolicy.thumbnailContent(
            message: "Thumbnail saved.",
            imageBase64: "large-jpeg-base64",
            imageByteCount: ImageResponsePolicy.inlineThumbnailMaxBytes + 1,
            assetIdentifier: "asset/one",
            maxDimension: 1024,
            quality: 0.75
        )

        #expect(content.count == 2)
        guard case .text = content[0],
              case .resourceLink(let uri, _, _, _, let mimeType, _) = content[1] else {
            Issue.record("Expected text and resource link only")
            return
        }

        #expect(uri == "photos://export/asset%2Fone?variant=thumbnail&max_dimension=1024&quality=0.75")
        #expect(mimeType == PhotoResources.exportMimeType)
    }

    @Test("full response with max dimension includes bounded resource link")
    func fullResponseWithMaxDimensionIncludesBoundedResourceLink() {
        let content = ImageResponsePolicy.fullContent(
            message: "Image saved. To view: `open /tmp/full.jpg`",
            assetIdentifier: "asset/one",
            maxDimension: 2048,
            quality: 0.8
        )

        #expect(content.count == 2)
        guard case .text(let text, _, _) = content[0],
              case .resourceLink(let uri, _, _, _, let mimeType, _) = content[1] else {
            Issue.record("Expected text and bounded full export resource link")
            return
        }

        #expect(text.contains("open /tmp/full.jpg"))
        #expect(uri == "photos://export/asset%2Fone?variant=full&max_dimension=2048&quality=0.8")
        #expect(mimeType == PhotoResources.exportMimeType)
    }

    @Test("full response without max dimension is text only")
    func fullResponseWithoutMaxDimensionIsTextOnly() {
        let content = ImageResponsePolicy.fullContent(
            message: "Image saved. To view: `open /tmp/full.jpg`",
            assetIdentifier: "asset/one",
            maxDimension: nil,
            quality: 0.8
        )

        #expect(content.count == 1)
        guard case .text(let text, _, _) = content[0] else {
            Issue.record("Expected text only")
            return
        }

        #expect(text.contains("open /tmp/full.jpg"))
    }
}
