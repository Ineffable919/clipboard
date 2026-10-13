import Foundation

@MainActor
final class LinkPreviewQueue {
    static let shared = LinkPreviewQueue()

    private let maxConcurrentLoads = 2
    private var pending: [(id: UUID, operation: @MainActor () async -> Void)] = []
    private var running: [UUID: Task<Void, Never>] = [:]

    func enqueue(_ operation: @escaping @MainActor () async -> Void) -> UUID {
        let id = UUID()
        pending.append((id, operation))
        startNext()
        return id
    }

    func cancel(_ id: UUID) {
        pending.removeAll { $0.id == id }
        running[id]?.cancel()
    }

    private func startNext() {
        while running.count < maxConcurrentLoads, !pending.isEmpty {
            let entry = pending.removeFirst()
            running[entry.id] = Task { @MainActor in
                defer {
                    // 取消后也要等实际加载结束，才能释放并发名额
                    running[entry.id] = nil
                    startNext()
                }
                guard !Task.isCancelled else { return }
                await entry.operation()
            }
        }
    }
}
