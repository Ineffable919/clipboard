//
//  MCPHTTPRequest.swift
//  Clipboard
//
//  Created by crown on 2026/11/13
//

import Foundation

/// 解析后的 HTTP/1.1 请求
nonisolated struct MCPHTTPRequest {
    let method: String
    let path: String
    /// 键为小写
    let headers: [String: String]
    var body: Data

    /// 请求头解析结果；`length` 为声明的 body 长度
    struct Head {
        let method: String
        let path: String
        let headers: [String: String]
        let length: Int
    }

    static let headerTerminator = Data("\r\n\r\n".utf8)

    /// 解析请求行与请求头（不含结尾空行）
    static func parseHead(_ data: Data) -> Head? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var lines = text.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return nil }

        let parts = lines.removeFirst().split(separator: " ")
        guard parts.count == 3, parts[2].hasPrefix("HTTP/") else { return nil }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        // 不支持分块传输；MCP 客户端的 JSON-RPC 请求都带 Content-Length
        guard headers["transfer-encoding"] == nil else { return nil }
        let length = headers["content-length"].flatMap { Int($0) } ?? 0
        guard length >= 0 else { return nil }

        // 去掉 query，仅保留路径
        let path = String(parts[1].split(separator: "?", maxSplits: 1).first ?? "")
        return Head(method: String(parts[0]), path: path, headers: headers, length: length)
    }
}

/// 待发送的 HTTP 响应
nonisolated struct MCPHTTPResponse {
    let status: Int
    var headers: [String: String] = [:]
    var body = Data()

    static func status(_ code: Int, allow: String? = nil) -> Self {
        Self(status: code, headers: allow.map { ["Allow": $0] } ?? [:])
    }

    static func json(_ body: Data) -> Self {
        Self(status: 200, headers: ["Content-Type": "application/json"], body: body)
    }

    var serialized: Data {
        var lines = ["HTTP/1.1 \(status) \(Self.reason(status))"]
        var all = headers
        all["Content-Length"] = String(body.count)
        all["Connection"] = "close"
        for (name, value) in all.sorted(by: { $0.key < $1.key }) {
            lines.append("\(name): \(value)")
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8) + body
    }

    private static func reason(_ code: Int) -> String {
        switch code {
        case 200: "OK"
        case 202: "Accepted"
        case 400: "Bad Request"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 413: "Content Too Large"
        case 431: "Request Header Fields Too Large"
        default: "Error"
        }
    }
}
