import MCP

enum ServerMetadata {
    static let name = "PhotosMCP"
    static let version = "1.0.0"
    static let sdkSpecSupport = "swift-sdk 0.12.1, MCP spec 2025-11-25"

    static let capabilities = Server.Capabilities(
        logging: .init(),
        resources: .init(),
        tools: .init(listChanged: true)
    )
}
