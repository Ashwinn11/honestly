import Foundation

enum AppLink {
    static let affirmations = URL(string: "honestly://affirmations")

    static func opensAffirmations(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "honestly"
            && url.host?.lowercased() == "affirmations"
            && (url.path.isEmpty || url.path == "/")
    }
}
