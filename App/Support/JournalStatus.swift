import Foundation

struct BlockingPresentation {
    let authorized: Bool
    let hasSelection: Bool
    let hasPremium: Bool
    let isWithinWindow: Bool
    let ritualDone: Bool

    var isConfigured: Bool { authorized && hasSelection && hasPremium }
    var isScheduledNow: Bool { isConfigured && isWithinWindow }
    var isHoldingApps: Bool { isScheduledNow && !ritualDone }
}

enum JournalStatusCopy {
    static func streak(current: Int, best: Int, total: Int) -> String {
        if current == 0 {
            return "A new morning. A fresh start."
        }
        if current > 1 && current >= best {
            return "Longest yet — keep the sun rising."
        }
        return "One morning at a time."
    }
}
