import Foundation

// MARK: - JSON-RPC ID

enum JSONRPCId {
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

struct JSONRPCRequest {
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

enum JSONRPC {
    static func success(id: JSONRPCId, result: Any) -> String {
        serialize(["jsonrpc": "2.0", "id": id.jsonValue, "result": result])
    }

    static func error(id: JSONRPCId, code: Int, message: String) -> String {
        serialize([
            "jsonrpc": "2.0",
            "id": id.jsonValue,
            "error": ["code": code, "message": message]
        ])
    }

    private static func serialize(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }
}
