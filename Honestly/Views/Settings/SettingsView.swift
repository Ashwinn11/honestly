import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var journalManager: JournalManager
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var localization: LocalizationManager

    @State private var showLanguagePicker = false
    @State private var showAppPicker = false
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var showCloudOptions = false
    @State private var cloudMessage: String?
    @State private var cloudBusy = false
    @State private var legalDoc: LegalDoc?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusCard

                section("Language") {
                    SettingsRow(icon: "globe", iconBG: Theme.happy,
                                title: "App Language",
                                subtitle: localization.language.nativeName,
                                accessory: .chevron) {
                        showLanguagePicker = true
                    }
                }

                section("App blocking") {
                    SettingsRow(icon: "apps.iphone", iconBG: Theme.confused,
                                title: "Choose Apps to Block", accessory: .chevron) {
                        if subscriptionManager.isPremium { showAppPicker = true }
                        else { showPaywall = true }
                    }
                }

                section("Membership") {
                    SettingsRow(icon: "crown.fill", iconBG: Theme.orange,
                                title: subscriptionManager.isPremium ? "morning club member" : "join morning club",
                                subtitle: "Manage Membership", accessory: .external) {
                        if subscriptionManager.isPremium {
                            openURL("https://apps.apple.com/account/subscriptions")
                        } else { showPaywall = true }
                    }
                }

                section("iCloud backup") {
                    SettingsRow(icon: "icloud.fill", iconBG: Theme.sad,
                                title: "iCloud Sync",
                                subtitle: "back up or restore your entries.",
                                accessory: .chevron) {
                        showCloudOptions = true
                    }
                    .confirmationDialog("iCloud", isPresented: $showCloudOptions, titleVisibility: .visible) {
                        Button("Back up now") { backUp() }
                        Button("Restore from backup") { restore() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Back up your entries to iCloud, or restore from your latest backup.")
                    }
                }

                section("Legal") {
                    SettingsRow(icon: "hand.raised.fill", iconBG: Theme.cry,
                                title: "Privacy Policy", accessory: .chevron) {
                        legalDoc = .privacy
                    }
                    SettingsRow(icon: "doc.text.fill", iconBG: Theme.confused,
                                title: "Terms of Service", accessory: .chevron) {
                        legalDoc = .terms
                    }
                }

                section("Data") {
                    SettingsRow(icon: "trash.fill", iconBG: Theme.awful,
                                title: "Delete all data", accessory: .chevron) {
                        showDeleteConfirm = true
                    }
                    .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("Delete everything", role: .destructive) {
                            journalManager.deleteAllData()
                            blockingManager.stopBlocking()
                            blockingManager.stopMonitoring()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes all journal entries, streaks, and plant progress, and returns you to the start. This can't be undone.")
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
            .contentColumn()
        }
        .background(Theme.pageBackground)
        .familyActivityPicker(isPresented: $showAppPicker, selection: $blockingManager.selection)
        .onChange(of: blockingManager.selection) { _, newValue in
            blockingManager.saveSelection(newValue)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView()
                .columnSheet()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
                .environmentObject(subscriptionManager)
                .columnSheet()
        }
        .sheet(item: $legalDoc) { doc in
            Group {
                if doc == .privacy { PrivacyPolicyView() } else { TermsOfServiceView() }
            }
            .columnSheet()
        }
        .alert("iCloud", isPresented: Binding(get: { cloudMessage != nil }, set: { if !$0 { cloudMessage = nil } })) {
            Button("OK", role: .cancel) { cloudMessage = nil }
        } message: {
            Text(cloudMessage ?? "")
        }
        .onAppear { blockingManager.refreshAuthorizationStatus() }
    }

    private func backUp() {
        guard !cloudBusy else { return }
        cloudBusy = true
        Task {
            do {
                try await BackupManager.shared.backUp(entries: journalManager.entries)
                cloudMessage = String(format: L("Backed up %lld entries to iCloud."), journalManager.entries.count)
            } catch {
                cloudMessage = L("Backup failed. Check your iCloud connection.")
            }
            cloudBusy = false
        }
    }

    private func restore() {
        guard !cloudBusy else { return }
        cloudBusy = true
        Task {
            do {
                if let backup = try await BackupManager.shared.latestBackup() {
                    journalManager.restore(from: backup.entries)
                    cloudMessage = String(format: L("Restored %lld entries from iCloud."), backup.entries.count)
                } else {
                    cloudMessage = L("No backup found in iCloud yet.")
                }
            } catch {
                cloudMessage = L("Restore failed. Check your iCloud connection.")
            }
            cloudBusy = false
        }
    }

    // MARK: header + status

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("your little", size: 18)
            Text("Settings")
                .font(AppFont.title(34))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // Real status: not-authorized → authorized-but-no-apps → active.
    private enum BlockState { case needsAuth, needsApps, active }
    private var blockState: BlockState {
        if !blockingManager.isAuthorized { return .needsAuth }
        if blockingManager.selectedCount == 0 { return .needsApps }
        return .active
    }

    private var statusCard: some View {
        Button {
            switch blockState {
            case .needsAuth: Task { await blockingManager.requestAuthorization() }
            case .needsApps: if subscriptionManager.isPremium { showAppPicker = true } else { showPaywall = true }
            case .active:    showAppPicker = true
            }
        } label: {
            AppCard(padding: 20) {
                HStack(spacing: 16) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 50)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(statusTitle)
                            .font(AppFont.cardTitle(22))
                            .foregroundStyle(Theme.ink)
                        Text(statusSubtitle)
                            .font(AppFont.accent(16))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var statusTitle: String {
        switch blockState {
        case .needsAuth: return L("screen time's off.")
        case .needsApps: return L("nothing's guarded yet.")
        case .active:    return L("your mornings are guarded.")
        }
    }
    private var statusIcon: String {
        switch blockState {
        case .needsAuth: return "exclamationmark.shield.fill"
        case .needsApps: return "lock.open.fill"
        case .active:    return "lock.shield.fill"
        }
    }
    private var statusColor: Color {
        blockState == .active ? Theme.orange : Theme.inkFaint
    }
    private var statusSubtitle: String {
        switch blockState {
        case .needsAuth: return L("turn it on so we can guard your mornings.")
        case .needsApps: return L("pick the apps to block until you journal.")
        case .active:
            let n = blockingManager.selectedCount
            return n == 1
                ? L("1 app rests until you journal each morning.")
                : String(format: L("%lld apps rest until you journal each morning."), n)
        }
    }


    // MARK: helpers

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)
            content()
        }
        .padding(.horizontal, 20)
    }

    private func sectionHeader(_ t: String) -> some View {
        Eyebrow(t, size: 18).padding(.horizontal, 4)
    }

    private func openURL(_ s: String) {
        guard let url = URL(string: s) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Rows

private enum RowAccessory { case chevron, external, none }

private struct SettingsRow: View {
    let icon: String
    let iconBG: Color
    let title: String
    var subtitle: String? = nil
    var accessory: RowAccessory = .chevron
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBadge(icon: icon, bg: iconBG)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(AppFont.bodyBold(17))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(AppFont.accent(15))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                Spacer()
                switch accessory {
                case .chevron:  Image(systemName: "chevron.right").foregroundStyle(Theme.inkFaint)
                case .external: Image(systemName: "arrow.up.right").foregroundStyle(Theme.inkFaint)
                case .none:     EmptyView()
                }
            }
            .padding(16)
            .appCardStyle()
        }
        .buttonStyle(.plain)
    }
}

private struct IconBadge: View {
    let icon: String
    let bg: Color
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 44, height: 44)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.ink, lineWidth: 2))
    }
}
