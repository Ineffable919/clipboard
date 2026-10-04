import AppKit

@MainActor
enum MCPClientIconLoader {
    private static let cache = NSCache<NSString, NSImage>()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()

    static func load(_ address: String) async -> NSImage? {
        if let image = cache.object(forKey: address as NSString) { return image }
        guard let url = URL(string: address) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let image = NSImage(data: data)
            else { return nil }

            cache.setObject(image, forKey: address as NSString)
            return image
        } catch {
            return nil
        }
    }
}
