import SwiftUI

// Individual screens, presented as sheets from Settings and the paywall.

struct PrivacyPolicyView: View {
    var body: some View { LegalScreen(doc: .privacy) }
}

struct TermsOfServiceView: View {
    var body: some View { LegalScreen(doc: .terms) }
}

private struct LegalScreen: View {
    let doc: LegalDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.pageBackground
            VStack(spacing: 0) {
                HStack {
                    Eyebrow("honestly", size: 18)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").headerCircle()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(doc.title)
                            .font(AppFont.title(30))
                            .foregroundStyle(Theme.ink)
                        Text("Last updated: \(doc.lastUpdated)")
                            .font(AppFont.caption(13))
                            .foregroundStyle(Theme.inkFaint)
                        Text(doc.body)
                            .font(AppFont.body(16))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(5)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            }
        }
    }
}
