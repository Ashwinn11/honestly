import SwiftUI
import WidgetKit

/// Reminder timing lives here. Affirmations use the same topics everywhere in the app.
struct AffirmationDeliverySettingsScreen: View {
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    @AppStorage("affirmationNudgeOn", store: SharedState.defaults) private var enabled = false
    @State private var reminderTimes = [AffirmationNudge.defaultMinutes]
    @State private var reminderDays = Array(1...7)
    @State private var notifDenied = false

    private let weekdaySymbols = Calendar.current.veryShortStandaloneWeekdaySymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryHeader(title: "Affirmation delivery", onBack: { dismiss() })
                .padding(.bottom, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Daily reminders")
                        card {
                            toggleRow("Affirmation reminders", detail: "Affirmations at your times, plus a writing nudge at 8 pm")
                        }
                        if enabled {
                            card {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(loc: "Times")
                                        .font(Fonts.ui(13, .bold)).foregroundStyle(Palette.inkSofter)
                                    ForEach(reminderTimes.indices, id: \.self) { index in
                                        HStack {
                                            DatePicker("", selection: timeBinding(index), displayedComponents: .hourAndMinute)
                                                .labelsHidden().tint(Palette.amber)
                                            Spacer()
                                            if reminderTimes.count > 1 {
                                                IconTileButton(icon: "minus", size: 36, iconSize: 13) { removeTime(index) }
                                                    .accessibilityLabel(Text(loc: "Remove reminder time"))
                                            }
                                        }
                                    }
                                    if reminderTimes.count < 3 {
                                        Button(action: addTime) {
                                            Label("Add a time", systemImage: "plus")
                                                .font(Fonts.ui(14, .bold)).foregroundStyle(Palette.amberDeep)
                                                .frame(minHeight: 44)
                                        }
                                    }
                                    Text(loc: "Days")
                                        .font(Fonts.ui(13, .bold)).foregroundStyle(Palette.inkSofter).padding(.top, 4)
                                    HStack(spacing: 6) {
                                        ForEach(1...7, id: \.self) { day in
                                            let symbol = weekdaySymbols[(day - 1) % 7]
                                            Button { toggleDay(day) } label: {
                                                Text(symbol.uppercased())
                                                    .font(Fonts.ui(12, .bold))
                                                    .foregroundStyle(reminderDays.contains(day) ? .white : Palette.inkSofter)
                                                    .frame(maxWidth: .infinity, minHeight: 40)
                                                    .background(reminderDays.contains(day) ? Palette.amber : Palette.paper,
                                                                in: Circle())
                                                    .overlay(Circle().strokeBorder(reminderDays.contains(day) ? Palette.ink : Palette.outlineSoft,
                                                                             lineWidth: reminderDays.contains(day) ? 2 : 1))
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(Text(Calendar.current.weekdaySymbols[(day - 1) % 7]))
                                            .accessibilityAddTraits(reminderDays.contains(day) ? .isSelected : [])
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Affirmation widgets")
                        if premium.isPremium {
                            Text(loc: "Widgets show affirmations from your selected topics.")
                                .font(Fonts.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            card {
                                Button { flow.showPaywall() } label: {
                                    Label("Unlock this widget with Premium", systemImage: "lock.fill")
                                        .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .padding(20)
        .capWidth(Metrics.maxContentWidth)
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            reminderTimes = AffirmationNudge.times
            reminderDays = AffirmationNudge.weekdays
        }
        .onChange(of: reminderTimes) { _, _ in saveDeliveryChanges() }
        .onChange(of: reminderDays) { _, _ in saveDeliveryChanges() }
        .onChange(of: enabled) { _, isOn in
            guard isOn else { AffirmationNudge.cancel(); return }
            Task {
                guard await AffirmationNudge.activate() else {
                    enabled = false
                    notifDenied = true
                    return
                }
                saveDeliveryChanges()
            }
        }
        .alert("Notifications are switched off", isPresented: $notifDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Your affirmations can't reach you yet — allow notifications for Honestly in Settings and they'll find their way back.")
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
                .padding(16)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.outlineSoft, lineWidth: 1.3))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(loc: title).font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
    }

    private func toggleRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc: title).font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                Text(loc: detail).font(Fonts.ui(12, .medium)).foregroundStyle(Palette.inkSofter)
            }
            Spacer(minLength: 4)
            AmberToggle(isOn: Binding(get: { enabled }, set: { value in
                if !premium.isPremium && value { flow.showPaywall() } else { enabled = value }
            }))
        }
    }

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(get: {
            let minutes = reminderTimes.indices.contains(index) ? reminderTimes[index] : AffirmationNudge.defaultMinutes
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            guard reminderTimes.indices.contains(index) else { return }
            reminderTimes[index] = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        })
    }

    private func addTime() {
        let start = ((reminderTimes.max() ?? AffirmationNudge.defaultMinutes) + 240) % 1440
        let next = (0..<1440).map { (start + $0) % 1440 }.first { candidate in
            reminderTimes.allSatisfy { abs($0 - candidate) >= 60 && abs($0 - candidate) <= 1380 }
        } ?? start
        reminderTimes.append(next)
    }

    private func removeTime(_ index: Int) {
        guard reminderTimes.indices.contains(index), reminderTimes.count > 1 else { return }
        reminderTimes.remove(at: index)
    }

    private func toggleDay(_ day: Int) {
        if reminderDays.contains(day) {
            guard reminderDays.count > 1 else { return }
            reminderDays.removeAll { $0 == day }
        } else { reminderDays.append(day); reminderDays.sort() }
    }

    private func saveDeliveryChanges() {
        SharedState.defaults.set(reminderTimes, forKey: SharedState.Key.affirmationReminderTimes)
        SharedState.defaults.set(reminderDays, forKey: SharedState.Key.affirmationReminderWeekdays)
        WidgetCenter.shared.reloadAllTimelines()
        AffirmationNudge.schedule()
    }
}
