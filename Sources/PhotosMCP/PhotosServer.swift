import Foundation
import MCP
import Photos

actor PhotosServer {
    private let server: Server
    private let observability = Observability()

    init(server: Server) {
        self.server = server
    }

    func start(transport: some Transport) async throws {
        await registerHandlers()
        try await server.start(transport: transport)
        await emitLog(
            level: .notice,
            logger: "photosmcp.server",
            data: await observability.eventPayload(
                event: "server.started",
                status: "ready"
            )
        )
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

        // SetLoggingLevel
        await server.withMethodHandler(SetLoggingLevel.self) { [weak self] params in
            guard let self = self else { throw MCPError.internalError("Server deallocated") }
            await self.observability.setMinimumLevel(params.level)
            await self.emitLog(
                level: .notice,
                logger: "photosmcp.server",
                data: await self.observability.eventPayload(
                    event: "logging.level_changed",
                    status: params.level.rawValue
                )
            )
            return Empty()
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
        await server.withMethodHandler(ReadResource.self) { [weak self] params in
            guard let self = self else { throw MCPError.internalError("Server deallocated") }
            return try await self.handleResourceRead(params)
        }
    }

    private func listAllTools() async -> ListTools.Result {
        .init(tools: ToolDefinitions.all)
    }

    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        try Self.validateKnownToolName(params.name)

        let start = ContinuousClock.now
        await emitLog(
            level: .info,
            logger: params.name == "diagnose_photos_mcp" ? "photosmcp.diagnostics" : "photosmcp.tool",
            data: await observability.eventPayload(
                event: "tool.started",
                status: "started",
                toolName: params.name
            )
        )
        if params.name == "diagnose_photos_mcp" {
            return try await loggedToolResult(
                toolName: params.name,
                start: start,
                result: DiagnosticsTools.diagnose(arguments: params.arguments)
            )
        }

        do {
            try await PhotosAccess.ensureAuthorized()
        } catch is PhotosAccessError {
            let result = ToolError.permissionDenied()
            return await loggedToolResult(toolName: params.name, start: start, result: result)
        } catch {
            await logThrownToolFailure(toolName: params.name, start: start)
            throw error
        }

        let result: CallTool.Result
        do {
            switch params.name {
            case "list_albums":
                result = try await LibraryTools.listAlbums(arguments: params.arguments)
            case "get_library_stats":
                result = try await LibraryTools.getLibraryStats(arguments: params.arguments)
            case "search_photos":
                result = try await SearchTools.searchPhotos(arguments: params.arguments)
            case "get_album_contents":
                result = try await AlbumTools.getAlbumContents(arguments: params.arguments)
            case "get_asset_details":
                result = try await AssetTools.getAssetDetails(arguments: params.arguments)
            case "get_asset_classifications":
                result = try await AssetTools.getAssetClassifications(arguments: params.arguments)
            case "get_photo_thumbnail":
                result = try await ImageTools.getPhotoThumbnail(arguments: params.arguments)
            case "get_photo_full":
                result = try await ImageTools.getPhotoFull(arguments: params.arguments)
            case "get_photos_by_place":
                result = try await SearchTools.getPhotosByPlace(arguments: params.arguments)
            case "get_photos_by_location":
                result = try await SearchTools.getPhotosByLocation(arguments: params.arguments)
            case "get_photos_by_date":
                result = try await SearchTools.getPhotosByDate(arguments: params.arguments)
            case "list_moments":
                result = try await LibraryTools.listMoments(arguments: params.arguments)
            case "diagnose_photos_mcp":
                result = try DiagnosticsTools.diagnose(arguments: params.arguments)
            default:
                throw MCPError.invalidParams("Unknown tool: \(params.name)")
            }
        } catch {
            await logThrownToolFailure(toolName: params.name, start: start)
            throw error
        }
        return await loggedToolResult(toolName: params.name, start: start, result: result)
    }

    private func loggedToolResult(
        toolName: String,
        start: ContinuousClock.Instant,
        result: CallTool.Result
    ) async -> CallTool.Result {
        let durationMs = Observability.durationMs(since: start)
        let envelope = ToolError.envelope(from: result)
        let failed = result.isError == true
        let isDiagnostics = toolName == "diagnose_photos_mcp"
        await emitLog(
            level: failed ? .warning : .notice,
            logger: isDiagnostics ? "photosmcp.diagnostics" : "photosmcp.tool",
            data: await observability.eventPayload(
                event: isDiagnostics ? "diagnostics.completed" : (failed ? "tool.failed" : "tool.completed"),
                status: failed ? "error" : "ok",
                toolName: toolName,
                durationMs: durationMs,
                error: envelope
            )
        )
        return result
    }

    private func logThrownToolFailure(toolName: String, start: ContinuousClock.Instant) async {
        await emitLog(
            level: .error,
            logger: toolName == "diagnose_photos_mcp" ? "photosmcp.diagnostics" : "photosmcp.tool",
            data: Observability.eventPayload(
                event: "tool.failed",
                status: "error",
                toolName: toolName,
                durationMs: Observability.durationMs(since: start),
                errorCode: "internal.unhandled_error",
                errorCategory: "internal"
            )
        )
    }

    static func validateKnownToolName(_ name: String) throws {
        guard isKnownTool(name) else {
            throw MCPError.invalidParams("Unknown tool: \(name)")
        }
    }

    static func isKnownTool(_ name: String) -> Bool {
        ToolDefinitions.all.contains { $0.name == name }
    }

    private func handleResourceRead(_ params: ReadResource.Parameters) async throws -> ReadResource.Result {
        let start = ContinuousClock.now
        let resourceKind = Observability.resourceKind(from: params.uri)
        do {
            try await PhotosAccess.ensureAuthorized()
            let result = try await PhotoResources.read(uri: params.uri)
            await emitLog(
                level: .notice,
                logger: "photosmcp.resource",
                data: await observability.eventPayload(
                    event: "resource.read_completed",
                    status: "ok",
                    resourceKind: resourceKind,
                    durationMs: Observability.durationMs(since: start)
                )
            )
            return result
        } catch let error as PhotoResources.ResourceError {
            await logResourceFailure(resourceKind: resourceKind, start: start, category: "resource")
            switch error {
            case .assetNotFound:
                throw MCPError.invalidParams("Resource not found")
            case .invalidURI(let message):
                throw MCPError.invalidParams(message)
            case .unsupportedMediaType:
                throw MCPError.invalidParams(error.localizedDescription)
            }
        } catch is PhotosAccessError {
            await logResourceFailure(resourceKind: resourceKind, start: start, category: "permission")
            throw MCPError.serverError(code: -32003, message: "Photos library access is not available")
        } catch {
            await logResourceFailure(resourceKind: resourceKind, start: start, category: "internal")
            throw MCPError.internalError(error.localizedDescription)
        }
    }

    private func logResourceFailure(
        resourceKind: Observability.ResourceKind,
        start: ContinuousClock.Instant,
        category: String
    ) async {
        await emitLog(
            level: .warning,
            logger: "photosmcp.resource",
            data: Observability.eventPayload(
                event: "resource.read_failed",
                status: "error",
                resourceKind: resourceKind,
                durationMs: Observability.durationMs(since: start),
                errorCode: "resource.read_failed",
                errorCategory: category
            )
        )
    }

    private func emitLog(level: LogLevel, logger: String, data: Value) async {
        guard await observability.isEnabled(level) else { return }
        do {
            try await server.log(level: level, logger: logger, data: data)
        } catch {
            // Diagnostics must never break tool/resource handling.
        }
    }
}
