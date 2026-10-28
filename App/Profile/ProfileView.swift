import SwiftUI
import FamilyControls
import StoreKit

struct ProfileView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(PromptLibrary.self) private var prompts
    @Environment(AffirmationList.self) private var affirmations
    @Environment(CoverStore.self) private var covers
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @State private var showPicker = false
    @State private var confirmDelete = false
    @State private var showICloud = false
    @State private var cloudBusy = false
    @State private var cloudMessage: CloudMessage?

    private enum CloudMessage {
        case backedUp(Int)
        case backupFailed
        case restored(Int)
        case restoreNotFound
    }

    var body: some View {
        @Bindable var st = screenTime
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                Text("You").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                    .fixedSize()
                Text("Little rituals, big mornings.")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 5)

                heroCard.padding(.top, 16)
                subscriptionCard.padding(.top, 16)
                settingsCard.padding(.top, 16)

                sectionEyebrow("Account")
                accountCard
                sectionEyebrow("About")
                aboutCard
                deleteCard.padding(.top, 16)
                #if DEBUG
                debugCard.padding(.top, 16)
                #endif

                // OpenMoji's CC BY-SA 4.0 license requires this credit to ship with the stickers.
                Text("Stickers: OpenMoji.org · CC BY-SA 4.0")
                    .font(Fonts.ui(10.5, .semibold)).foregroundStyle(Palette.inkSofter)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $st.selection)
        .alert("Delete all data?", isPresented: $confirmDelete) {
            Button("Delete everything", role: .destructive) {
                store.deleteAll(); screenTime.wipe(); affirmations.clear(); prompts.clear(); covers.reset(); Haptics.rigid()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This erases every page, your streak, and your app selection, and returns you to the start. It can't be undone.")
        }
        .overlay { if cloudBusy { ProgressView().controlSize(.large).tint(Palette.amber)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black.opacity(0.06)) } }
    }

    // MARK: Subscription — top of screen, above everything else
    private var subscriptionCard: some View {
        Group {
            if premium.isPremium {
                if premium.isLifetime {
                    settingRow {
                        rowText("Honestly Premium", "Lifetime access · paid once")
                    } trailing: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Palette.success)
                    }
                } else {
                    Button {
                        openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                    } label: {
                        settingRow {
                            rowText("Honestly Premium", "Manage your subscription")
                        } trailing: { chevron }
                    }
                    .buttonStyle(RowPressStyle())
                }
            } else {
                Button {
                    Haptics.tap()
                    flow.showPaywall()
                } label: {
                    settingRow {
                        rowText("Go Premium", "Full history, iCloud backup & app blocking")
                    } trailing: {
                        Text(loc: "Upgrade").font(Fonts.ui(13, .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Palette.amber, in: Capsule())
                            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                    }
                }
                .buttonStyle(RowPressStyle())
            }
        }
        .softCard(padding: 0, radius: Radius.card)
    }

    #if DEBUG
    // MARK: Debug — not in release builds
    private var debugCard: some View {
        Button {
            Haptics.success()
            store.seedSampleYear()
        } label: {
            settingRow {
                rowText("Debug: add 12 months of pages", "Add up to 10 sample pages per month")
            } trailing: {
                Image(systemName: "hammer.fill").foregroundStyle(Palette.inkSofter)
            }
        }
        .buttonStyle(RowPressStyle())
        .outlinedSurface(radius: Radius.card)
    }
    #endif

    // MARK: Hero
    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            SunMark(size: 54, tint: Palette.sunTint)
                .rotationEffect(.degrees(-8)).offset(x: -2, y: 14).floaty(period: 6)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(store.streak)").font(Fonts.display(44, .heavy)).foregroundStyle(.white)
                    Text("day streak").font(Fonts.ui(16, .heavy)).foregroundStyle(.white)
                }
                Text(loc: JournalStatusCopy.streak(current: store.streak, best: store.bestStreak,
                                                  total: store.totalMornings))
                    .font(Fonts.ui(13, .semibold)).foregroundStyle(.white.opacity(0.92)).padding(.top, 4)
                Rectangle().fill(.white.opacity(0.35)).frame(height: 1.5).padding(.top, 14)
                HStack(spacing: 26) {
                    stat("\(store.totalMornings)", "total mornings")
                    stat("\(store.bestStreak)", "best streak")
                }
                .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Palette.amber, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
        .tactile(6, cornerRadius: Radius.card)
    }
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Fonts.display(20, .heavy)).foregroundStyle(.white)
            Text(loc: label).font(Fonts.ui(11, .bold)).foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: Settings
    private var appsRowTitle: String { screenTime.authorized ? "Apps on hold" : "Approve Screen Time" }
    private var appsRowSubtitle: String {
        screenTime.authorized ? "Managed by Screen Time" : "Grant access to start blocking distracting apps"
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                AffirmationsScreen().toolbar(.hidden, for: .navigationBar)
            } label: {
                settingRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc: "Manage affirmations").font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                        Text(loc: "Choose topics and add your own")
                            .font(Fonts.ui(12, .medium)).foregroundStyle(Palette.inkSofter)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } trailing: { chevron }
            }
            .buttonStyle(RowPressStyle())
            divider
            NavigationLink {
                AffirmationDeliverySettingsScreen()
            } label: {
                settingRow {
                    rowText("Affirmation delivery", "Reminder timing and widget access")
                } trailing: { chevron }
            }
            .buttonStyle(RowPressStyle())
            divider
            settingRow {
                rowText("Morning window", "Apps stay asleep until your page is done")
            } trailing: {
                Text("From 4:00 AM").font(Fonts.ui(14, .bold)).foregroundStyle(Palette.inkSoft)
            }
            divider
            Button {
                Haptics.tap()
                flow.requiring(.appBlocking, premium: premium) {
                    Task { if await screenTime.ensureAuthorizedForPicker() { showPicker = true } }
                }
            } label: {
                settingRow {
                    rowText(appsRowTitle, appsRowSubtitle)
                } trailing: {
                    if screenTime.authorized {
                        Text(loc: screenTime.selectionSummary)
                            .font(Fonts.ui(14, .bold)).foregroundStyle(Palette.amberDeep)
                    } else {
                        chevron
                    }
                }
            }
            .buttonStyle(RowPressStyle())
            divider
            LanguagePickerRow()
        }
        .softCard(padding: 0, radius: Radius.card)
    }

    // MARK: Account
    private var accountCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.tap()
                flow.requiring(.iCloudBackup, premium: premium) { showICloud = true }
            } label: {
                settingRow {
                    rowText("iCloud backup", "Manually back up or restore your pages")
                } trailing: {
                    HStack(spacing: 9) {
                        if !premium.allows(.iCloudBackup) { PremiumLockBadge() }
                        chevron
                    }
                }
            }
            .buttonStyle(RowPressStyle())
            .confirmationDialog("iCloud backup", isPresented: $showICloud, titleVisibility: .visible) {
                Button("Back up to iCloud now") {
                    Task {
                        cloudBusy = true
                        let ok = await store.backupToCloud()
                        cloudBusy = false
                        if ok { Haptics.success() }
                        cloudMessage = ok ? .backedUp(store.totalMornings) : .backupFailed
                    }
                }
                Button("Restore from iCloud") {
                    Task {
                        cloudBusy = true
                        let n = await store.restoreFromCloud()
                        cloudBusy = false
                        if let n { Haptics.success(); cloudMessage = .restored(n) }
                        else { cloudMessage = .restoreNotFound }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Save a snapshot of your pages to iCloud, or restore your latest one.")
            }
            .alert("iCloud", isPresented: Binding(get: { cloudMessage != nil },
                                                  set: { if !$0 { cloudMessage = nil } })) {
                Button("OK", role: .cancel) { cloudMessage = nil }
            } message: {
                switch cloudMessage {
                case .backedUp(let n) where n == 1: Text("Backed up 1 page to iCloud.")
                case .backedUp(let n): Text("Backed up \(n) pages to iCloud.")
                case .backupFailed: Text("Couldn't reach iCloud. Check you're signed in and try again.")
                case .restored(let n) where n == 1: Text("Restored 1 page from your iCloud backup.")
                case .restored(let n): Text("Restored \(n) pages from your iCloud backup.")
                case .restoreNotFound: Text("No iCloud backup found.")
                case nil: EmptyView()
                }
            }
        }
        .softCard(padding: 0, radius: Radius.card)
    }

    // MARK: About
    private var aboutCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.tap()
                ReviewPrompt.rate(requestReview) { openURL($0) }
            } label: {
                settingRow {
                    rowText("Rate Honestly")
                } trailing: {
                    HStack(spacing: 9) {
                        InkGlyph(kind: .star, size: 15, fill: Palette.amber, lineWidth: 1.2)
                        chevron
                    }
                }
            }
            .buttonStyle(RowPressStyle())
            divider
            legalRow("Terms of Service", .terms)
            divider
            legalRow("Privacy Policy", .privacy)
        }
        .softCard(padding: 0, radius: Radius.card)
    }
    private func legalRow(_ title: String, _ doc: LegalDoc) -> some View {
        NavigationLink {
            LegalView(doc: doc).toolbar(.hidden, for: .navigationBar)
        } label: {
            settingRow {
                Text(loc: title).font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } trailing: { chevron }
        }
        .buttonStyle(RowPressStyle())
    }

    private var deleteCard: some View {
        Button { confirmDelete = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.danger)
                Text("Delete all data").font(Fonts.ui(15, .heavy)).foregroundStyle(Palette.danger)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .softCard(padding: 0, radius: Radius.card)
    }

    // MARK: Row building blocks
    private func sectionEyebrow(_ text: String) -> some View {
        Eyebrow(text: text, color: Palette.eyebrowSoft, tracking: 1.2, size: 11)
            .padding(.top, 22).padding(.bottom, 8).padding(.horizontal, 4)
    }
    private func settingRow<L: View, T: View>(@ViewBuilder _ leading: () -> L,
                                              @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            leading()
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18).padding(.vertical, 15)
        .contentShape(Rectangle())
    }
    private func rowText(_ title: String, _ subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(loc: title).font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
            if let subtitle {
                Text(loc: subtitle).font(Fonts.ui(12, .medium)).foregroundStyle(Palette.inkSofter)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var divider: some View { Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1).padding(.leading, 18) }
    private var chevron: some View {
        Image(systemName: "chevron.forward").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.hairline)
    }
}

private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Palette.pressedRow : .clear)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
