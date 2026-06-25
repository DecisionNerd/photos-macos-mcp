import Testing
@testable import PhotosMCP

struct PrivacyBoundaryTests {
    @Test("Photos access policy uses least available read capable scope")
    func photosAccessPolicyUsesLeastAvailableReadCapableScope() {
        #expect(PhotosAccess.requiredAccessLevel == .readWrite)
    }

    @Test("permission denied error remains privacy safe")
    func permissionDeniedErrorRemainsPrivacySafe() {
        let result = ToolError.permissionDenied()

        guard case .text(let text, _, _)? = result.content.first,
              case .object(let meta)? = result._meta?[ToolError.metaKey] else {
            Issue.record("Expected typed permission error")
            return
        }

        #expect(result.isError == true)
        #expect(meta["category"] == .string("permission"))
        #expect(meta["code"] == .string("permission.photos_access_denied"))
        #expect(!text.contains("asset/"))
        #expect(!text.contains("latitude"))
        #expect(!text.contains("longitude"))
        #expect(!text.contains("/tmp/"))
    }

    @Test("temp cleanup policy removes stale JPEG exports only")
    func tempCleanupPolicyRemovesStaleJPEGExportsOnly() {
        #expect(TempFileCleanup.shouldClean(
            pathExtension: "jpg",
            ageSeconds: TempFileCleanup.maxAgeSeconds + 1
        ))
        #expect(!TempFileCleanup.shouldClean(
            pathExtension: "jpg",
            ageSeconds: TempFileCleanup.maxAgeSeconds
        ))
        #expect(!TempFileCleanup.shouldClean(
            pathExtension: "txt",
            ageSeconds: TempFileCleanup.maxAgeSeconds + 1
        ))
    }
}
