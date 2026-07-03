import ManagedSettings
import Foundation

/// Handles taps on the custom shield. There's no public way to launch the host app
/// from here, so the primary button simply dismisses the blocked app — sending the
/// user off to open Honestly and do their ritual. Secondary defers a moment.
final class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:   return .close
        case .secondaryButtonPressed: return .defer
        default:                      return .none
        }
    }
}
