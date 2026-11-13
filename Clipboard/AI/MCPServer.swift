//
//  MCPServer.swift
//  Clipboard
//
//  Created by crown on 2026/11/13
//

import Foundation
import Network
import Observation

/// 本机 MCP 服务（Streamable HTTP，单一 `/mcp` 端点）
///
/// 只监听 127.0.0.1，随「启用 MCP」开关启停；端口可在设置中修改。
/// 端口被占用时不会自动换端口（客户端配置里的 URL 会失效），而是进入 `.failed` 状态交由用户处理。
@MainActor @Observable
final class MCPServer {
    static let shared = MCPServer()

    static let defaultPort = 38417
    static let portRange: ClosedRange<Int> = 1024 ... 65535

    enum Status: Equatable {
        case stopped
        case running
        case failed
    }

    private(set) var status: Status = .stopped
    private(set) var port: Int

    var endpoint: String {
        "http://127.0.0.1:\(port)/mcp"
    }

    @ObservationIgnored private let handler = MCPHandler()
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private let isPreview: Bool

    private init() {
        let saved = PasteUserDefaults.mcpPort
        port = Self.portRange.contains(saved) ? saved : Self.defaultPort
        isPreview = false
    }

    init(previewStatus: Status, port: Int = MCPServer.defaultPort) {
        status = previewStatus
        self.port = port
        isPreview = true
    }

    func sync() {
        MCPEnableFlag.isEnabled ? start() : stop()
    }

    /// 修改端口并在运行时重启服务
    /// - Returns: 端口是否合法
    @discardableResult
    func setPort(_ newPort: Int) -> Bool {
        guard Self.portRange.contains(newPort) else { return false }
        guard newPort != port else {
            // 失败状态下重复提交相同端口视为重试
            if status == .failed { sync() }
            return true
        }
        port = newPort
        guard !isPreview else { return true }
        PasteUserDefaults.mcpPort = newPort
        stop()
        sync()
        return true
    }

    func start() {
        guard !isPreview, listener == nil else { return }
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: endpointPort)

        do {
            let listener = try NWListener(using: parameters)
            let handler = handler
            listener.newConnectionHandler = { connection in
                Task.detached {
                    await MCPHTTPConnection(connection: connection, handler: handler).serve()
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.update(state, of: listener) }
            }
            listener.start(queue: DispatchQueue(label: "com.crown.clipboard.mcp.listener"))
            self.listener = listener
        } catch {
            log.error("MCP 服务启动失败: \(error.localizedDescription)")
            status = .failed
        }
    }

    func stop() {
        guard !isPreview else { return }
        listener?.cancel()
        listener = nil
        status = .stopped
    }

    private func update(_ state: NWListener.State, of source: NWListener) {
        guard listener === source else { return }
        switch state {
        case .ready:
            log.info("MCP 服务已监听 \(endpoint)")
            status = .running
        case let .failed(error):
            log.error("MCP 服务异常: \(error.localizedDescription)")
            source.cancel()
            listener = nil
            status = .failed
        default:
            break
        }
    }
}
