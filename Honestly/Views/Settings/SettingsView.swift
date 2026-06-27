import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var journalManager: JournalManager
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

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
                }

                aboutFooter
                Spacer(minLength: 120)
            }
            .padding(.top, 8)
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $blockingManager.selection)
        .onChange(of: blockingManager.selection) { _, newValue in
            blockingManager.saveSelection(newValue)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
                .environmentObject(subscriptionManager)
        }
        .sheet(item: $legalDoc) { doc in
            if doc == .privacy { PrivacyPolicyView() } else { TermsOfServiceView() }
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
        .confirmationDialog("iCloud", isPresented: $showCloudOptions, titleVisibility: .visible) {
            Button("Back up now") { backUp() }
            Button("Restore from backup") { restore() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Back up your entries to iCloud, or restore from your latest backup.")
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
                cloudMessage = "Backed up \(journalManager.entries.count) entries to iCloud."
            } catch {
                cloudMessage = "Backup failed. Check your iCloud connection."
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
                    cloudMessage = "Restored \(backup.entries.count) entries from iCloud."
                } else {
                    cloudMessage = "No backup found in iCloud yet."
                }
            } catch {
                cloudMessage = "Restore failed. Check your iCloud connection."
            }
            cloudBusy = false
        }
    }

    // MARK: header + status

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow("your little", size: 18)
                Text("Settings")
                    .font(AppFont.title(34))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Mascot(kind: .clover, size: 40)
        }
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
                    Mascot(kind: .sun, size: 56)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(statusTitle)
                                .font(AppFont.cardTitle(22))
                                .foregroundStyle(Theme.ink)
                            Text(statusBadge)
                                .font(AppFont.accent(15))
                                .foregroundStyle(Theme.orange)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .overlay(Capsule().stroke(Theme.orange, lineWidth: 1.5))
                        }
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
        case .needsAuth: return "you're all clear."
        case .needsApps: return "almost there."
        case .active:    return "you're all set."
        }
    }
    private var statusBadge: String {
        blockState == .active ? "active" : "ready"
    }
    private var statusSubtitle: String {
        switch blockState {
        case .needsAuth: return "enable screen time to get started."
        case .needsApps: return "choose the apps to block each morning."
        case .active:    return "blocking \(blockingManager.selectedCount) app\(blockingManager.selectedCount == 1 ? "" : "s") until you journal."
        }
    }

    private var aboutFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("About")
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(Theme.inkFaint)
            }
            .font(AppFont.body(15))
            Button { openURL("mailto:ashwinnanbazhagan@gmail.com") } label: {
                Text("Contact support")
                    .font(AppFont.body(15))
                    .foregroundStyle(Theme.orange)
            }
            Text("© 2026 Ashwin Anbazhagan")
                .font(AppFont.caption(12))
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
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
                    Text(title)
                        .font(AppFont.bodyBold(17))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
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
