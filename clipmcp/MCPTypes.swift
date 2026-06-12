import Foundation

// MARK: - JSON-RPC ID

enum JSONRPCId {
    case string(String)
    case int(Int)

    init?(from value: Any?) {
        switch value {
        case let s as String: self = .string(s)
        case let i as Int:    self = .int(i)
        default:              return nil
        }
    }

    var jsonValue: Any {
        switch self {
        case .string(let s): return s
        case .int(let i):    return i
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
        self.params = json["params"] as? [String: Any] ?? [:]
        self.id = json.keys.contains("id") ? JSONRPCId(from: json["id"]) : nil
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
            "error": ["code": code, "message": message],
        ])
    }

    private static func serialize(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }
}
