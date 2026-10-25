import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(AffirmationList.self) private var affirmations
    @Environment(PremiumManager.self) private var premium

    @State private var index = 0
    @State private var forward = true
    @State private var picks: [String] = []

    private enum Beat: Int, CaseIterable {
        case brand, problem, lock, plan, affirm, social, notif, paywall
    }
    private let beats = Beat.allCases
    private var beat: Beat { beats[index] }

    private var dotTotal: Int { beats.count - 1 }
    private var canGoBack: Bool { index > 0 }

    var body: some View {
        ZStack {
            PaperBackground()
            if beat == .paywall {
                PaywallView(onClose: finish)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                beatView
                    .id(index)
                    .transition(slide)
                    .capWidth(Metrics.maxContentWidth)
            }
        }
        .overlay(alignment: .top) {
            if beat == .brand {          // language picker lives on the very first screen
                LanguagePickerPill().padding(.top, 6)
            }
        }
        .animation(Motion.gentle, value: index)
        .onAppear { picks = affirmations.chosen }
    }

    private var slide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    // MARK: - Per-beat body

    @ViewBuilder private var beatView: some View {
        switch beat {
        case .brand:
            chrome(primary: .init(title: "Good morning") { advance() }) {
                OnbIllustration(kind: .brand)
            }

        case .problem:
            chrome(primary: .init(title: "Continue") { advance() }) {
                VStack(spacing: 26) {
                    OnbHeader(eyebrow: "Your morning", title: AppContent.onbProblemTitle)
                    OnbIllustration(kind: .noise)
                }
            }

        case .lock:
            chrome(primary: .init(title: "Continue") { advance() }) {
                lockAnimation
            }

        case .plan:
            chrome(primary: .init(title: "This is me") { advance() }) {
                OnbPlanView()
            }

        case .affirm:
            chrome(primary: .init(title: picks.isEmpty ? (affirmations.availableLibrary.isEmpty ? "Continue" : "Pick at least one") : "These are mine",
                                  enabled: !picks.isEmpty || affirmations.availableLibrary.isEmpty) {
                affirmations.set(picks)
                advance()
            }) {
                OnbAffirmView(picks: $picks, isPremium: premium.isPremium)
            }

        case .social:
            chrome(primary: .init(title: "Continue") { advance() }) {
                OnbSocialProofView()
            }

        case .notif:
            chrome(primary: .init(title: "Allow notifications") { requestNotifications() },
                   secondary: .init(title: "Maybe later") { advance() }) {
                VStack(spacing: 26) {
                    OnbHeader(eyebrow: "Stay connected", title: AppContent.notifTitle)
                    let lines = Affirmations.rotation(from: picks, premium: premium.isPremium)
                    NotifStack(first: lines.first ?? "", second: lines.count > 1 ? lines[1] : lines.first ?? "")
                }
            }

        case .paywall:
            EmptyView()   // handled at the top level
        }
    }

    // MARK: - Shared chrome (content + footer grouped and centered)

    @ViewBuilder
    private func chrome<C: View>(primary: FooterButton,
                                 secondary: FooterLink? = nil,
                                 @ViewBuilder content: @escaping () -> C) -> some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView {
                    content()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height, alignment: .center)
                        .padding(.horizontal, 26)   // padding lives here so shadows bleed freely
                        .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            footer(primary: primary, secondary: secondary)   // pinned at the bottom
                .padding(.horizontal, 26)
        }
        .padding(.top, 8)
        .padding(.bottom, 30)
    }

    private func footer(primary: FooterButton, secondary: FooterLink?) -> some View {
        VStack(spacing: 18) {
            OnbDots(index: index, total: dotTotal)
            HStack(spacing: 12) {
                if canGoBack { backButton }
                ctaButton(primary)
            }
            if let secondary {
                HStack(spacing: 12) {
                    // Mirror the back button's gutter so the link centers under the CTA, not the footer.
                    if canGoBack { Color.clear.frame(width: DesignScale.s(56), height: 1) }
                    Button { Haptics.tap(); secondary.action() } label: {
                        Text(loc: secondary.title)
                            .font(Fonts.ui(14.5, .bold)).foregroundStyle(Palette.inkSofter)
                            .frame(maxWidth: .infinity).padding(.vertical, 2)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                }
            }
        }
    }

    private var backButton: some View {
        IconTileButton(icon: "chevron.backward", size: 56, iconSize: 16,
                       iconColor: Palette.ink, fill: Palette.cream, radius: 17) { back() }
    }

    private func ctaButton(_ b: FooterButton) -> some View {
        Button {
            guard b.enabled else { return }
            Haptics.tap(); b.action()
        } label: {
            Text(loc: b.title)
                .font(Fonts.ui(16.5, .heavy))
                .foregroundStyle(b.enabled ? .white : Palette.inkSofter)
                .frame(maxWidth: .infinity, minHeight: DesignScale.s(56))
                .background(b.enabled ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.ink.opacity(0.06)),
                            in: RoundedRectangle(cornerRadius: DesignScale.s(17), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(17), style: .continuous)
                    .stroke(Palette.ink, lineWidth: b.enabled ? 2 : 0))
                .tactile(b.enabled ? 4 : 0, cornerRadius: DesignScale.s(17))
        }
        .buttonStyle(PressableStyle())
        .disabled(!b.enabled)
        .animation(Motion.snappy, value: b.enabled)
    }

    private struct FooterButton {
        let title: String
        var enabled: Bool = true
        let action: () -> Void
    }
    private struct FooterLink {
        let title: String
        let action: () -> Void
    }

    // MARK: - App-locking (passive — icons lock themselves, nothing to tap)

    @State private var lockedCount = 0

    private var lockAnimation: some View {
        VStack(spacing: 26) {
            OnbHeader(eyebrow: "Your attention, on your terms", title: AppContent.lockTitle)

            let displayBrands: [(Int, Brand)] = Array([Brand.instagram, .tiktok, .whatsapp, .snapchat].enumerated())
            HStack(spacing: 0) {
                ForEach(displayBrands, id: \.1) { i, b in
                    let locked = i < lockedCount
                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            BrandIcon(brand: b, size: 68)
                                .grayscale(locked ? 1 : 0)
                                .opacity(locked ? 0.5 : 1)
                            if locked {
                                lockBadge.transition(.scale.combined(with: .opacity))
                            }
                        }
                        Text(b.displayName)
                            .font(Fonts.ui(12, .bold))
                            .foregroundStyle(locked ? Palette.inkSofter : Palette.ink)
                    }
                    .animation(Motion.pop, value: locked)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task { await animateLocks() }
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(Palette.ink, in: Circle())
            .overlay(Circle().stroke(Palette.paper, lineWidth: 2))
            .offset(x: 6, y: -6)
    }

    private func animateLocks() async {
        try? await Task.sleep(for: .seconds(0.4))
        for i in 1...4 {
            withAnimation(Motion.pop) { lockedCount = i }
            Haptics.tap()
            try? await Task.sleep(for: .seconds(0.18))
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard index < beats.count - 1 else { return }
        forward = true
        withAnimation(Motion.gentle) { index += 1 }
    }

    private func back() {
        guard index > 0 else { return }
        forward = false
        withAnimation(Motion.gentle) { index = max(0, index - 1) }
    }

    private func requestNotifications() {
        Task {
            await AffirmationNudge.requestPermission()
            advance()
        }
    }

    private func finish() {
        SharedState.onboardingComplete = true
        Haptics.success()
        onFinish()
    }
}

// MARK: - Dotted progress

private struct OnbDots: View {
    let index: Int      // current beat (0-based)
    let total: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i <= index ? Palette.amber : Palette.ink.opacity(0.12))
                    .frame(width: i == index ? 8 : 6, height: i == index ? 8 : 6)
            }
        }
        .animation(Motion.snappy, value: index)
    }
}

// MARK: - Plan reveal (how the ritual works — no personalization, same for everyone)
private struct OnbHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Eyebrow(text: eyebrow, tracking: 1.6, size: 12)
            Text(loc: title)
                .font(Fonts.display(24, .bold))
                .foregroundStyle(Palette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private struct OnbPlanView: View {
    var body: some View {
        VStack(spacing: 28) {
            OnbHeader(eyebrow: "How it works", title: "A little space to\nhear yourself.")

            ZStack {
                SoftGlow(color: Palette.sunDisc, opacity: 0.22, size: 320)
                morningPage
                    .rotationEffect(.degrees(-4))

                Image(systemName: "pencil")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(Palette.amber)
                    .shadow(color: Palette.ink.opacity(0.14), radius: 3, x: 2, y: 4)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 112, y: 62)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            HStack(alignment: .top, spacing: 0) {
                step(symbol: "face.smiling", title: "Check in")
                connector
                step(symbol: "pencil.line", title: "Write")
                connector
                step(symbol: "lock.open", title: "Begin")
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var morningPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(loc: "A moment for me")
                    .font(Fonts.ui(12, .heavy))
                    .foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 8)
                SunMark(size: 28)
            }

            Text(loc: "Today, I need…")
                .font(Fonts.display(23, .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(Palette.ink.opacity(0.12))
                        .frame(height: 2)
                        .padding(.trailing, index == 2 ? 48 : 0)
                }
            }
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Palette.amberDeep)
                Text(loc: "A few honest lines are enough.")
                    .foregroundStyle(Palette.inkSoft)
            }
            .font(Fonts.ui(11, .semibold))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: 260, alignment: .leading)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Palette.ink, lineWidth: 2))
        .tactile(5, cornerRadius: 20)
        .shadow(color: Palette.ink.opacity(0.09), radius: 18, x: 0, y: 12)
    }

    private func step(symbol: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 50, height: 50)
                .background(Palette.iconTile, in: Circle())
                .overlay(Circle().stroke(Palette.outlineSoft, lineWidth: 1.5))
                .accessibilityHidden(true)
            Text(loc: title)
                .font(Fonts.ui(12, .heavy))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var connector: some View {
        Image(systemName: "arrow.forward")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.inkSofter)
            .padding(.top, 19)
            .accessibilityHidden(true)
    }
}

// MARK: - Pick your affirmations — the rotation Home, the widget and the daily notification draw
// from. Free picks stop at `Affirmations.freeLimit`; no upsell here, the paywall is a few beats on.
private struct OnbAffirmView: View {
    @Binding var picks: [String]
    let isPremium: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                OnbHeader(eyebrow: "Your affirmations, in your order",
                          title: "Pick words you need.\nSee one each day.")
            }
            .frame(maxWidth: .infinity)

            AffirmationPicker(selection: $picks, isPremium: isPremium)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Notification cards — a floating-card illustration of today's and yesterday's daily
// affirmation, drawn from the lines just picked.

private struct NotifCard: View {
    let text: String
    var time: String = "now"

    var body: some View {
        HStack(alignment: .top, spacing: DesignScale.s(12)) {
            Image("app-mark").resizable().scaledToFill()
                .frame(width: DesignScale.s(42), height: DesignScale.s(42))
                .clipShape(RoundedRectangle(cornerRadius: DesignScale.s(10), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(10), style: .continuous).stroke(Palette.ink.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: DesignScale.s(3)) {
                HStack {
                    Text(loc: "Today's affirmation").font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(loc: time).font(Fonts.ui(12, .semibold)).foregroundStyle(Palette.inkSofter)
                }
                Affirmations.text(text)
                    .font(Fonts.ui(13.5, .semibold)).foregroundStyle(Color(hex: "5A4A38"))
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(EdgeInsets(top: DesignScale.s(15), leading: DesignScale.s(15), bottom: DesignScale.s(15), trailing: DesignScale.s(16)))
        .frame(maxWidth: DesignScale.s(330))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignScale.s(22), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignScale.s(22), style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .shadow(color: Color(hex: "78501E").opacity(0.14), radius: DesignScale.s(16), y: DesignScale.s(9))
    }
}

private struct NotifStack: View {
    let first: String
    let second: String
    @State private var showFirst = false
    @State private var showSecond = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            if showFirst {
                NotifCard(text: first)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity))
            }
            if showSecond {
                NotifCard(text: second, time: "yesterday")
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .task { await run() }
    }

    private func run() async {
        guard !reduceMotion else {
            showFirst = true; showSecond = true
            Haptics.notificationSound()
            return
        }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(Motion.snappy) { showFirst = true }
        Haptics.notificationSound()
        try? await Task.sleep(for: .seconds(1.0))
        withAnimation(Motion.snappy) { showSecond = true }
        Haptics.notificationSound()
    }
}

// MARK: - Social proof

private struct OnbSocialProofView: View {
    private var sp: SocialProof { AppContent.socialProof }
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 16) {
            OnbHeader(eyebrow: "From the App Store", title: "A small part of\nsomeone’s morning.")
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { _ in
                    InkGlyph(kind: .star, size: 28, fill: Color(hex: "F6C33F"), lineWidth: 1.4)
                }
            }
            if sp.hasStats {
                Text(sp.rating).font(Fonts.display(40, .heavy)).foregroundStyle(Palette.ink)
            }

            VStack(spacing: 12) {
                ForEach(sp.quotes) { q in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("“\(Text(loc: q.text))”")
                            .font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("— \(q.author)")
                            .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                        if locale.language.languageCode?.identifier != "en" {
                            Text(loc: "Translated from English")
                                .font(Fonts.ui(11, .medium)).foregroundStyle(Palette.inkSofter)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(padding: 16)
                }
            }
        }
        // Glow anchored near the top (behind the stars/heading), so it stays put as the cards grow.
        .background(alignment: .top) { SoftGlow(color: Palette.sunDisc, opacity: 0.16, size: 300).offset(y: 40) }
    }

}

// MARK: - Illustrations (one per slide kind) — retained from the original deck

private struct OnbIllustration: View {
    let kind: OnbKind

    var body: some View {
        switch kind {
        case .brand:  brand
        case .noise:  noise
        }
    }

    private var brand: some View {
        VStack(spacing: 0) {
            ZStack {
                SoftGlow(color: Palette.sunDisc, opacity: 0.22, size: 280)
                SunMark(size: 118).spin(period: 26)
                InkGlyph(kind: .sparkle, size: 24, fill: Color(hex: "F6C33F"))
                    .offset(x: -74, y: -60).floaty(period: 4)
                InkGlyph(kind: .heart, size: 20, fill: Color(hex: "F19DA6"))
                    .offset(x: 76, y: -44).floaty(period: 5, delay: 0.4)
            }
            .floaty(period: 6)
            .padding(.bottom, 22)
            Text("Honestly").font(Fonts.display(52, .heavy)).foregroundStyle(Palette.ink)
            Text("The first few minutes of your day, finally yours.")
                .font(Fonts.ui(16, .semibold)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 280).padding(.top, 18)
        }
    }

    private static let notifDelays: [Double] = [0.1, 0.28, 0.46, 0.64]

    private var noise: some View {
        ZStack {
            notifChip(.instagram, "2 new likes on your photo", tilt: -4)
                .offset(x: DesignScale.s(-62), y: DesignScale.s(-92)).floaty(amplitude: 5, period: 3.4).popIn(delay: Self.notifDelays[0])
            notifChip(.tiktok, "24 new videos for you", tilt: 5)
                .offset(x: DesignScale.s(60), y: DesignScale.s(-32)).floaty(amplitude: 5, period: 3.8, delay: 0.2).popIn(delay: Self.notifDelays[1])
            notifChip(.snapchat, "New snap from a friend", tilt: -5)
                .offset(x: DesignScale.s(-60), y: DesignScale.s(32)).floaty(amplitude: 5, period: 3.2, delay: 0.4).popIn(delay: Self.notifDelays[2])
            notifChip(.whatsapp, "3 new messages", tilt: 4)
                .offset(x: DesignScale.s(62), y: DesignScale.s(92)).floaty(amplitude: 5, period: 3.6, delay: 0.1).popIn(delay: Self.notifDelays[3])
        }
        .frame(width: DesignScale.s(250), height: DesignScale.s(260))
        .task { await fireNotifHaptics() }
    }
    private func fireNotifHaptics() async {
        var elapsed = 0.0
        for delay in Self.notifDelays {
            try? await Task.sleep(for: .seconds(delay - elapsed))
            Haptics.tap()
            elapsed = delay
        }
    }
    private func notifChip(_ brand: Brand, _ teaser: String, tilt: Double) -> some View {
        HStack(spacing: DesignScale.s(9)) {
            BrandIcon(brand: brand, size: DesignScale.s(34))
            VStack(alignment: .leading, spacing: DesignScale.s(1)) {
                Text(brand.displayName).font(Fonts.ui(12.5, .heavy)).foregroundStyle(Palette.ink)
                Text(loc: teaser).font(Fonts.ui(11, .semibold)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(EdgeInsets(top: DesignScale.s(9), leading: DesignScale.s(9), bottom: DesignScale.s(9), trailing: DesignScale.s(14)))
        .frame(width: DesignScale.s(192), alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: DesignScale.s(16), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignScale.s(16), style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .shadow(color: Color(hex: "78501E").opacity(0.14), radius: DesignScale.s(12), y: DesignScale.s(7))
        .rotationEffect(.degrees(tilt))
    }
}
