//
//  MCPTypes.swift
//  Clipboard
//
//  Created by crown on 2026/6/2
//

import Foundation

// MARK: - JSON-RPC ID

nonisolated enum JSONRPCId {
    case string(String)
    case int(Int)

    init?(from value: Any?) {
        switch value {
        case let string as String: self = .string(string)
        case let integer as Int: self = .int(integer)
        default: return nil
        }
    }

    var jsonValue: Any {
        switch self {
        case let .string(string): string
        case let .int(integer): integer
        }
    }
}

// MARK: - Request

nonisolated struct JSONRPCRequest {
    let id: JSONRPCId?
    let method: String
    let params: [String: Any]

    init?(json: [String: Any]) {
        guard let method = json["method"] as? String else { return nil }
        self.method = method
        params = json["params"] as? [String: Any] ?? [:]
        id = json.keys.contains("id") ? JSONRPCId(from: json["id"]) : nil
    }
}

// MARK: - Response builders

nonisolated enum JSONRPC {
    static func success(id: JSONRPCId, result: Any) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id.jsonValue, "result": result]
    }

    static func error(id: JSONRPCId, code: Int, message: String) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id.jsonValue,
            "error": ["code": code, "message": message]
        ]
    }

    /// 无法解析请求体时的错误响应（id 为 null）
    static func parseError() -> Data? {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": NSNull(),
            "error": ["code": -32700, "message": "Parse error"]
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}
