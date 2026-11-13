//
//  MCPHTTPConnection.swift
//  Clipboard
//
//  Created by crown on 2026/11/13
//

import Foundation
import Network

/// 单个 TCP 连接：读取一个请求，写回一个响应后关闭
nonisolated struct MCPHTTPConnection {
    private static let maxHeader = 16 * 1024
    private static let maxBody = 2 * 1024 * 1024
    private static let timeout: Duration = .seconds(15)
    /// Network.framework 要求为连接提供回调队列
    private static let queue = DispatchQueue(label: "com.crown.clipboard.mcp.connection")

    let connection: NWConnection
    let handler: MCPHandler

    func serve() async {
        connection.start(queue: Self.queue)
        // 慢速/卡住的连接到时直接取消，使挂起的 receive 返回
        let watchdog = Task {
            try await Task.sleep(for: Self.timeout)
            connection.cancel()
        }
        defer {
            watchdog.cancel()
            connection.cancel()
        }

        let response: MCPHTTPResponse
        switch await readRequest() {
        case let .success(request): response = route(request)
        case let .failure(status): response = .status(status)
        case .none: return
        }
        await send(response.serialized)
    }

    // MARK: - Routing

    private func route(_ request: MCPHTTPRequest) -> MCPHTTPResponse {
        // 防 DNS rebinding / 浏览器跨站调用：Host 与 Origin 都必须是回环地址
        guard Self.isLoopback(host: request.headers["host"]) else { return .status(403) }
        if let origin = request.headers["origin"],
           !Self.isLoopback(host: URL(string: origin)?.host(percentEncoded: false)) {
            return .status(403)
        }

        guard request.path == "/mcp" else { return .status(404) }

        // 无状态、不主动推送：不提供 GET 的 SSE 流，也没有 session 可 DELETE
        guard request.method == "POST" else { return .status(405, allow: "POST") }

        if let version = request.headers["mcp-protocol-version"],
           !MCPHandler.supportedVersions.contains(version) {
            return .status(400)
        }

        guard let body = handler.handle(body: request.body) else { return .status(202) }
        return .json(body)
    }

    private static func isLoopback(host: String?) -> Bool {
        guard var host else { return false }
        // 去掉端口（保留 IPv6 的方括号）
        if host.hasPrefix("[") {
            if let end = host.firstIndex(of: "]") { host = String(host[...end]) }
        } else if let colon = host.firstIndex(of: ":") {
            host = String(host[..<colon])
        }
        return ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host.lowercased())
    }

    // MARK: - IO

    private enum ReadResult {
        case success(MCPHTTPRequest)
        case failure(Int)
    }

    /// nil 表示连接已断开，无需响应
    private func readRequest() async -> ReadResult? {
        var buffer = Data()
        var head: MCPHTTPRequest.Head?
        var bodyStart = 0

        while true {
            if head == nil, let range = buffer.range(of: MCPHTTPRequest.headerTerminator) {
                guard let parsed = MCPHTTPRequest.parseHead(buffer[..<range.lowerBound]) else {
                    return .failure(400)
                }
                guard parsed.length <= Self.maxBody else { return .failure(413) }
                head = parsed
                bodyStart = range.upperBound
            } else if head == nil, buffer.count > Self.maxHeader {
                return .failure(431)
            }

            if let head, buffer.count - bodyStart >= head.length {
                let body = buffer[bodyStart ..< bodyStart + head.length]
                return .success(MCPHTTPRequest(
                    method: head.method, path: head.path, headers: head.headers, body: Data(body)
                ))
            }

            guard let chunk = await receive() else { return nil }
            buffer.append(chunk)
        }
    }

    private func receive() async -> Data? {
        await withCheckedContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, error in
                continuation.resume(returning: error == nil ? data : nil)
            }
        }
    }

    private func send(_ data: Data) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.send(content: data, contentContext: .finalMessage, isComplete: true,
                            completion: .contentProcessed { _ in continuation.resume() })
        }
    }
}
