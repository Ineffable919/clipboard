//
//  MCPHandler.swift
//  Clipboard
//
//  Created by crown on 2026/6/2
//

import Foundation

/// MCP JSON-RPC 请求分发；无状态，可在任意线程调用
nonisolated struct MCPHandler {
    /// 按优先级从新到旧
    static let supportedVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

    private let tools = MCPTools()

    /// 处理一次 POST body（单个消息或批量数组）
    /// - Returns: 响应体；仅含通知/响应时返回 nil（对应 HTTP 202）
    func handle(body: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: body) else {
            return JSONRPC.parseError()
        }

        if let batch = object as? [[String: Any]] {
            let responses = batch.compactMap(handle(message:))
            guard !responses.isEmpty else { return nil }
            return try? JSONSerialization.data(withJSONObject: responses)
        }

        guard let message = object as? [String: Any] else {
            return JSONRPC.parseError()
        }
        guard let response = handle(message: message) else { return nil }
        return try? JSONSerialization.data(withJSONObject: response)
    }

    private func handle(message: [String: Any]) -> [String: Any]? {
        guard let request = JSONRPCRequest(json: message) else { return nil }

        // 通知不带 id，无需响应
        guard let id = request.id else { return nil }

        switch request.method {
        case "initialize":
            let requested = request.params["protocolVersion"] as? String
            let version = requested.flatMap { Self.supportedVersions.contains($0) ? $0 : nil }
                ?? Self.supportedVersions[0]
            return JSONRPC.success(id: id, result: [
                "protocolVersion": version,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "clipboard", "version": "1.0.0"]
            ])

        case "ping":
            return JSONRPC.success(id: id, result: [String: Any]())

        case "tools/list":
            return JSONRPC.success(id: id, result: ["tools": MCPTools.definitions])

        case "tools/call":
            return JSONRPC.success(id: id, result: tools.call(params: request.params))

        default:
            return JSONRPC.error(id: id, code: -32601, message: "Method not found: \(request.method)")
        }
    }
}
