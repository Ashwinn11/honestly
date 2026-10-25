import Foundation

enum AppLink {
    static let affirmations = URL(string: "honestly://affirmations")

    static func affirmation(_ line: String) -> URL? {
        var components = URLComponents(string: "honestly://affirmations")
        components?.queryItems = [URLQueryItem(name: "line", value: line)]
        return components?.url
    }

    static func affirmationLine(from url: URL) -> String? {
        guard opensAffirmations(url) else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "line" })?.value
    }

    static func opensAffirmations(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "honestly"
            && url.host?.lowercased() == "affirmations"
            && (url.path.isEmpty || url.path == "/")
    }
}
