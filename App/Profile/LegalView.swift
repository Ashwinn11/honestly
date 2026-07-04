import SwiftUI

enum LegalDoc: Identifiable {
    case terms, privacy

    var id: String { title }
    var title: String { self == .terms ? "Terms of Service" : "Privacy Policy" }
    var effective: String { "Effective July 2026" }
    var sections: [(heading: String, body: String)] { self == .terms ? Self.termsSections : Self.privacySections }

    static let privacySections: [(heading: String, body: String)] = [
        ("The short version",
         "Honestly is built to be private. Your morning pages — your moods, your writing, your gratitudes — belong to you. We don't sell them, mine them, or read them. There are no third-party trackers or advertising SDKs in this app."),
        ("What stays on your device",
         "Everything you write is stored locally on your iPhone. If you have iCloud enabled, your pages are backed up to your own private iCloud account (Apple's CloudKit) so they follow you between devices. We never receive a copy on our servers — your iCloud data is encrypted and accessible only to you."),
        ("Screen Time",
         "When you choose apps to keep asleep each morning, that selection is handled entirely by Apple's Screen Time (Family Controls) framework. Honestly is shown opaque tokens — never the names of the apps or websites you picked, and never any record of how you use them. That information never leaves your device and is never visible to us."),
        ("Purchases",
         "Honestly Premium is a one-time purchase processed by Apple. We use RevenueCat to verify your purchase and unlock premium features. This involves an anonymous purchase identifier only — no name, email, or contact information is required or collected."),
        ("Notifications",
         "If you turn on the morning nudge, a single local notification is scheduled on your device. It is generated on-device and is not sent through any server."),
        ("What we don't do",
         "We do not collect analytics, we do not fingerprint your device, we do not build a profile of you, and we do not share anything with advertisers. There is nothing to opt out of because there is nothing being gathered."),
        ("Your control",
         "You can delete every page and reset your history at any time from the You tab (\"Delete all data\"). Deleting the app removes all local data; disabling iCloud sync for Honestly removes the backup from your iCloud account."),
        ("Contact",
         "Questions about your privacy? Email ashwinnanbazhagan@gmail.com and a human will answer."),
    ]

    static let termsSections: [(heading: String, body: String)] = [
        ("Welcome",
         "These terms are the agreement between you and Honestly for your use of the app. By using Honestly, you agree to them. We've kept them plain."),
        ("Your license",
         "We grant you a personal, non-transferable license to use Honestly on devices you own or control, for your own morning ritual. The app and its design are ours; please don't copy, resell, or reverse-engineer it."),
        ("Honestly Premium",
         "Honestly Premium is a one-time purchase that unlocks your full history and additional features for the lifetime of the app on your Apple account. Purchases are handled and billed by Apple under Apple's terms. Refunds are managed by Apple through the App Store."),
        ("Your content",
         "Your pages are yours. You retain all rights to everything you write. We claim no ownership and take no license over your journal entries, moods, or gratitudes."),
        ("Acceptable use",
         "Use Honestly for your own reflection. Don't use it to break the law, and don't attempt to disrupt, probe, or misuse the app or the Screen Time features it relies on."),
        ("Screen Time & blocking",
         "Honestly uses Apple's Screen Time to help keep chosen apps asleep until your page is written. This is a supportive nudge, not a guarantee — the operating system ultimately controls app availability, and you remain responsible for your own device and choices."),
        ("No warranty",
         "Honestly is provided \"as is.\" We work hard to keep it reliable, but we can't promise it will be uninterrupted or error-free, and it is not a substitute for professional mental-health care."),
        ("Limitation of liability",
         "To the extent permitted by law, Honestly and its makers are not liable for any indirect or incidental damages arising from your use of the app."),
        ("Changes",
         "We may update these terms as the app evolves. If we make material changes, we'll note them here with a new effective date. Continued use means you accept the current terms."),
        ("Contact",
         "Reach us at ashwinnanbazhagan@gmail.com."),
    ]
}

struct LegalView: View {
    let doc: LegalDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SoftCircleButton(icon: "chevron.left", iconSize: 15) { dismiss() }
                        .padding(.bottom, 16)

                    Text(loc: doc.title).font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                    Eyebrow(text: doc.effective, color: Palette.inkSofter, tracking: 1.2, size: 11)
                        .padding(.top, 6).padding(.bottom, 22)

                    ForEach(Array(doc.sections.enumerated()), id: \.offset) { _, s in
                        Text(loc: s.heading)
                            .font(Fonts.display(19, .semibold)).foregroundStyle(Palette.ink)
                            .padding(.bottom, 7)
                        Text(loc: s.body)
                            .font(Fonts.ui(15, .medium)).foregroundStyle(Palette.inkBody)
                            .lineSpacing(6)
                            .padding(.bottom, 22)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 50)
                .capWidth(Metrics.maxContentWidth)   // centered column; PaperBackground stays full
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}
