import Foundation

enum StashURL {
    static func authenticated(_ path: String?, apiKey: String?) -> URL? {
        guard let path, !path.isEmpty, var components = URLComponents(string: path) else {
            return nil
        }
        if let apiKey, !apiKey.isEmpty {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "apikey", value: apiKey))
            components.queryItems = items
        }
        return components.url
    }
}
