import SwiftUI
import FamilyControls

struct ProfileView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(AppFlow.self) private var flow
    @Environment(\.openURL) private var openURL

    @AppStorage("morningNudgeOn", store: SharedState.defaults) private var nudgeOn = true
    @State private var showPicker = false
    @State private var confirmDelete = false
    @State private var showICloud = false
    @State private var cloudBusy = false
    @State private var cloudMessage: String?

    var body: some View {
        @Bindable var st = screenTime
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                Text("You").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                    .fixedSize()
                    .underlineSquiggle(Palette.sunDisc, weight: 4, height: 9)
                Text("Little rituals, big mornings.")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 5)

                heroCard.padding(.top, 16)
                settingsCard.padding(.top, 16)

                sectionEyebrow("Account")
                accountCard
                sectionEyebrow("About")
                aboutCard
                deleteCard.padding(.top, 16)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $st.selection)
        .alert("Delete all data?", isPresented: $confirmDelete) {
            Button("Delete everything", role: .destructive) {
                store.deleteAll(); screenTime.wipe(); Haptics.rigid()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This erases every page, your streak, and your app selection, and returns you to the start. It can't be undone.")
        }
        .confirmationDialog("iCloud backup", isPresented: $showICloud, titleVisibility: .visible) {
            Button("Back up to iCloud now") {
                Task {
                    cloudBusy = true
                    let ok = await store.backupToCloud()
                    cloudBusy = false
                    if ok { Haptics.success() }
                    cloudMessage = ok ? "Backed up \(store.totalMornings) page\(store.totalMornings == 1 ? "" : "s") to iCloud."
                                      : "Couldn't reach iCloud. Check you're signed in and try again."
                }
            }
            Button("Restore from iCloud") {
                Task {
                    cloudBusy = true
                    let n = await store.restoreFromCloud()
                    cloudBusy = false
                    if let n { Haptics.success(); cloudMessage = "Restored \(n) page\(n == 1 ? "" : "s") from your iCloud backup." }
                    else { cloudMessage = "No iCloud backup found." }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Save a snapshot of your pages to iCloud, or restore your latest one.")
        }
        .alert("iCloud", isPresented: Binding(get: { cloudMessage != nil },
                                              set: { if !$0 { cloudMessage = nil } })) {
            Button("OK", role: .cancel) { cloudMessage = nil }
        } message: { Text(cloudMessage ?? "") }
        .overlay { if cloudBusy { ProgressView().controlSize(.large).tint(Palette.amber)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black.opacity(0.06)) } }
        .onChange(of: nudgeOn) { _, on in
            if on { Task { if await MorningNudge.requestAuthorization() { MorningNudge.schedule() } } }
            else { MorningNudge.cancel() }
        }
    }

    // MARK: Hero
    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            SunMark(size: 54, tint: Color(hex: "FFF4E0"))
                .rotationEffect(.degrees(-8)).offset(x: -2, y: 14).floaty(period: 6)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(store.streak)").font(Fonts.display(44, .heavy)).foregroundStyle(.white)
                    Text("day streak").font(Fonts.ui(16, .heavy)).foregroundStyle(.white)
                }
                Text("Longest yet — keep the sun rising.")
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
        .background(Palette.amber, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .tactile(6, cornerRadius: 22)
    }
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Fonts.display(20, .heavy)).foregroundStyle(.white)
            Text(loc: label).font(Fonts.ui(11, .bold)).foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: Settings
    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingRow {
                rowText("Morning nudge", "One gentle notification at 6:45 AM")
            } trailing: {
                AmberToggle(isOn: $nudgeOn)
            }
            divider
            settingRow {
                rowText("Morning window", "Apps stay asleep until your page is done")
            } trailing: {
                Text("From 4:00 AM").font(Fonts.ui(14, .bold)).foregroundStyle(Palette.inkSoft)
            }
            divider
            Button {
                Task { if await screenTime.ensureAuthorizedForPicker() { showPicker = true } }
            } label: {
                settingRow {
                    rowText("Apps on hold", "Managed by Screen Time")
                } trailing: {
                    Text(loc: screenTime.selectionSummary)
                        .font(Fonts.ui(14, .bold)).foregroundStyle(Palette.amberDeep)
                }
            }
            .buttonStyle(RowPressStyle())
            divider
            LanguagePickerRow()
        }
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.5))
        .shadow(color: Color(hex: "78501E").opacity(0.08), radius: 13, y: 10)
    }

    // MARK: Account
    private var accountCard: some View {
        VStack(spacing: 0) {
            Button { showICloud = true } label: {
                settingRow {
                    rowText("iCloud sync", "Back up or restore your pages")
                } trailing: {
                    HStack(spacing: 9) {
                        Text("On").font(Fonts.ui(14, .bold)).foregroundStyle(Palette.success)
                        chevron
                    }
                }
            }
            .buttonStyle(RowPressStyle())
            divider
            Button { flow.showPaywall() } label: {
                settingRow {
                    rowText("Manage subscription", nil)
                } trailing: { chevron }
            }
            .buttonStyle(RowPressStyle())
        }
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.5))
        .shadow(color: Color(hex: "78501E").opacity(0.08), radius: 13, y: 10)
    }

    // MARK: About
    private var aboutCard: some View {
        VStack(spacing: 0) {
            Button {
                if let url = ReviewPrompt.writeReviewURL { Haptics.tap(); openURL(url) }
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
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.5))
        .shadow(color: Color(hex: "78501E").opacity(0.08), radius: 13, y: 10)
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
        }
        .buttonStyle(RowPressStyle())
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.5))
        .shadow(color: Color(hex: "78501E").opacity(0.08), radius: 13, y: 10)
    }

    // MARK: Row building blocks
    private func sectionEyebrow(_ text: String) -> some View {
        Eyebrow(text: text, color: Color(hex: "C0B29A"), tracking: 1.2, size: 11)
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
        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.hairline)
    }
}

private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(hex: "FAF5EE") : .clear)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
