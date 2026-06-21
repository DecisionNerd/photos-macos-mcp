import Foundation
import MCP
import Photos

actor PhotosServer {
    private let server: Server

    init(server: Server) {
        self.server = server
    }

    func start(transport: some Transport) async throws {
        await registerHandlers()
        try await server.start(transport: transport)
    }

    func waitUntilCompleted() async {
        await server.waitUntilCompleted()
    }

    private func registerHandlers() async {
        // ListTools
        await server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self = self else { throw MCPError.internalError("Server deallocated") }
            return await self.listAllTools()
        }

        // CallTool
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else { throw MCPError.internalError("Server deallocated") }
            return try await self.handleToolCall(params)
        }

        // ListResources
        await server.withMethodHandler(ListResources.self) { _ in
            ListResources.Result(resources: PhotoResources.listedResources, nextCursor: nil)
        }

        // ListResourceTemplates
        await server.withMethodHandler(ListResourceTemplates.self) { _ in
            ListResourceTemplates.Result(templates: PhotoResources.templates, nextCursor: nil)
        }

        // ReadResource
        await server.withMethodHandler(ReadResource.self) { params in
            return try await PhotosServer.handleResourceRead(params)
        }
    }

    private func listAllTools() async -> ListTools.Result {
        .init(tools: ToolDefinitions.all)
    }

    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        do {
            try await PhotosAccess.ensureAuthorized()
        } catch {
            return .init(
                content: [PhotoKitHelpers.textContent("Error: \(error.localizedDescription)")],
                isError: true
            )
        }

        switch params.name {
        case "list_albums":
            return try await LibraryTools.listAlbums(arguments: params.arguments)
        case "get_library_stats":
            return try await LibraryTools.getLibraryStats(arguments: params.arguments)
        case "search_photos":
            return try await SearchTools.searchPhotos(arguments: params.arguments)
        case "get_album_contents":
            return try await AlbumTools.getAlbumContents(arguments: params.arguments)
        case "get_asset_details":
            return try await AssetTools.getAssetDetails(arguments: params.arguments)
        case "get_asset_classifications":
            return try await AssetTools.getAssetClassifications(arguments: params.arguments)
        case "get_photo_thumbnail":
            return try await ImageTools.getPhotoThumbnail(arguments: params.arguments)
        case "get_photo_full":
            return try await ImageTools.getPhotoFull(arguments: params.arguments)
        case "get_photos_by_place":
            return try await SearchTools.getPhotosByPlace(arguments: params.arguments)
        case "get_photos_by_location":
            return try await SearchTools.getPhotosByLocation(arguments: params.arguments)
        case "get_photos_by_date":
            return try await SearchTools.getPhotosByDate(arguments: params.arguments)
        case "list_moments":
            return try await LibraryTools.listMoments(arguments: params.arguments)
        default:
            return .init(
                content: [PhotoKitHelpers.textContent("Unknown tool: \(params.name)")],
                isError: true
            )
        }
    }

    private static func handleResourceRead(_ params: ReadResource.Parameters) async throws -> ReadResource.Result {
        do {
            try await PhotosAccess.ensureAuthorized()
            return try await PhotoResources.read(uri: params.uri)
        } catch let error as PhotoResources.ResourceError {
            switch error {
            case .assetNotFound:
                throw MCPError.invalidParams("Resource not found")
            case .invalidURI(let message):
                throw MCPError.invalidParams(message)
            case .unsupportedMediaType:
                throw MCPError.invalidParams(error.localizedDescription)
            }
        } catch let error as PhotosAccessError {
            throw MCPError.invalidParams(error.localizedDescription)
        } catch {
            throw MCPError.internalError(error.localizedDescription)
        }
    }
}
