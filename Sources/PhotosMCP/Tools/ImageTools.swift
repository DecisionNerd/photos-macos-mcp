import Foundation
import MCP
import Photos

enum ImageTools {

    static func getPhotoThumbnail(arguments: [String: Value]?) async throws -> CallTool.Result {
        let assetId: String
        let maxDimension: Int
        let quality: CGFloat
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: ["asset_identifier", "max_dimension", "quality"])
            assetId = try ToolArgumentValidation.requiredString(arguments, name: "asset_identifier")
            maxDimension = try ToolArgumentValidation.int(arguments, name: "max_dimension", default: 512, min: 1)
            quality = CGFloat(try ToolArgumentValidation.double(arguments, name: "quality", default: 0.8, min: 0, max: 1))
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return ToolError.assetNotFound()
            }

            guard asset.mediaType == .image else {
                return ToolError.unsupportedMediaType(expected: "photo")
            }

            do {
                let imageData = try await ImageExport.thumbnail(asset: asset, maxDimension: maxDimension, quality: quality)
                let (filePath, _) = saveToTempFile(imageData, prefix: "photo_thumb")
                let w = min(asset.pixelWidth, maxDimension)
                let h = min(asset.pixelHeight, maxDimension)
                let msg: String
                if let path = filePath {
                    msg = "Thumbnail \(w)×\(h) saved. To view: `open \(path)`"
                } else {
                    msg = "Thumbnail \(w)×\(h) (save failed)"
                }
                return CallTool.Result(
                    content: ImageResponsePolicy.thumbnailContent(
                        message: msg,
                        imageBase64: imageData.base64EncodedString(),
                        imageByteCount: imageData.count,
                        assetIdentifier: assetId,
                        maxDimension: maxDimension,
                        quality: Double(quality)
                    ),
                    isError: false
                )
            } catch {
                return ToolError.exportFailed(kind: "thumbnail")
            }
        }.value
    }

    static func getPhotoFull(arguments: [String: Value]?) async throws -> CallTool.Result {
        let assetId: String
        let maxDimension: Int?
        let quality: CGFloat
        do {
            try ToolArgumentValidation.rejectUnknown(arguments, allowed: ["asset_identifier", "max_dimension", "quality"])
            assetId = try ToolArgumentValidation.requiredString(arguments, name: "asset_identifier")
            maxDimension = try ToolArgumentValidation.optionalInt(arguments, name: "max_dimension", min: 1)
            quality = CGFloat(try ToolArgumentValidation.double(arguments, name: "quality", default: 0.8, min: 0, max: 1))
        } catch let error as ToolArgumentValidation.Failure {
            return error.result
        }

        return await Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                return ToolError.assetNotFound()
            }

            guard asset.mediaType == .image else {
                return ToolError.unsupportedMediaType(expected: "photo")
            }

            var warning: String?
            if maxDimension == nil && (asset.pixelWidth > 4000 || asset.pixelHeight > 4000) {
                warning = "Warning: Full-resolution image is large (\(asset.pixelWidth)x\(asset.pixelHeight)). Consider max_dimension (e.g. 2048) to downscale."
            }

            do {
                let imageData = try await ImageExport.fullImage(
                    asset: asset,
                    maxDimension: maxDimension,
                    quality: quality
                )
                let outW = maxDimension.map { min(asset.pixelWidth, $0) } ?? asset.pixelWidth
                let outH = maxDimension.map { min(asset.pixelHeight, $0) } ?? asset.pixelHeight
                let (filePath, _) = saveToTempFile(imageData, prefix: "photo_full")
                var parts: [String] = []
                if let w = warning { parts.append(w) }
                parts.append("Image \(outW)×\(outH), \(imageData.count) bytes.")
                if let path = filePath {
                    parts.append("To view: `open \(path)`")
                }
                let content = ImageResponsePolicy.fullContent(
                    message: parts.joined(separator: " "),
                    assetIdentifier: assetId,
                    maxDimension: maxDimension,
                    quality: Double(quality)
                )
                return CallTool.Result(content: content, isError: false)
            } catch {
                return ToolError.exportFailed(kind: "full")
            }
        }.value
    }
}

enum ImageResponsePolicy {
    static let inlineThumbnailMaxBytes = 1_500_000

    static func thumbnailContent(
        message: String,
        imageBase64: @autoclosure () -> String,
        imageByteCount: Int,
        assetIdentifier: String,
        maxDimension: Int,
        quality: Double
    ) -> [Tool.Content] {
        var content = [PhotoKitHelpers.textContent(message)]
        if imageByteCount <= inlineThumbnailMaxBytes {
            content.append(.image(
                data: imageBase64(),
                mimeType: PhotoResources.exportMimeType,
                annotations: .init(audience: [.user], priority: 0.9),
                _meta: nil
            ))
        }
        content.append(PhotoResources.exportResourceLink(
            for: assetIdentifier,
            variant: .thumbnail,
            maxDimension: maxDimension,
            quality: quality
        ))
        return content
    }

    static func fullContent(
        message: String,
        assetIdentifier: String,
        maxDimension: Int?,
        quality: Double
    ) -> [Tool.Content] {
        var content = [PhotoKitHelpers.textContent(message)]
        if let maxDimension {
            content.append(PhotoResources.exportResourceLink(
                for: assetIdentifier,
                variant: .full,
                maxDimension: maxDimension,
                quality: quality
            ))
        }
        return content
    }
}

private let tempFilesSubdirName = "PhotosMCP"

private func saveToTempFile(_ data: Data, prefix: String) -> (path: String?, displayPath: String?) {
    let fm = FileManager.default
    let tmpDir = fm.temporaryDirectory.appendingPathComponent(tempFilesSubdirName, isDirectory: true)
    let baseDir: URL
    if (try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)) != nil {
        baseDir = tmpDir
        TempFileCleanup.cleanStaleFiles(in: tmpDir)
    } else {
        baseDir = fm.temporaryDirectory
    }

    let name = "\(prefix)_\(UUID().uuidString.prefix(8)).jpg"
    let fileURL = baseDir.appendingPathComponent(name)
    do {
        try data.write(to: fileURL)
        return (fileURL.path, fileURL.path)
    } catch {
        return (nil, nil)
    }
}

/// Cleans exported image temp files older than 1 hour to limit disk use and exposure window.
enum TempFileCleanup {
    static let maxAgeSeconds: TimeInterval = 3600  // 1 hour

    static func cleanStaleFiles(in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for url in contents where url.pathExtension == "jpg" {
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let creation = attrs[.creationDate] as? Date,
                  shouldClean(pathExtension: url.pathExtension, ageSeconds: Date().timeIntervalSince(creation)) else { continue }
            try? fm.removeItem(at: url)
        }
    }

    static func shouldClean(pathExtension: String, ageSeconds: TimeInterval) -> Bool {
        pathExtension == "jpg" && ageSeconds > maxAgeSeconds
    }
}
