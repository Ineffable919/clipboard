import Foundation

struct MCPHandler {
    private let tools = MCPTools()

    func handle(line: String) -> String? {
        guard
            let data = line.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let request = JSONRPCRequest(json: json)
        else { return nil }

        // Notifications carry no id and require no response.
        guard let id = request.id else { return nil }

        switch request.method {
        case "initialize":
            return JSONRPC.success(id: id, result: [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "clipboard", "version": "1.0.0"],
            ])

        case "tools/list":
            return JSONRPC.success(id: id, result: ["tools": MCPTools.definitions])

        case "tools/call":
            return JSONRPC.success(id: id, result: tools.call(params: request.params))

        default:
            return JSONRPC.error(id: id, code: -32601, message: "Method not found: \(request.method)")
        }
    }
}
