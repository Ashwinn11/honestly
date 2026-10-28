import SwiftUI
import WidgetKit
import UIKit

/// Reminder timing lives here. Affirmations use the same topics everywhere in the app.
struct AffirmationDeliverySettingsScreen: View {
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    @AppStorage("affirmationNudgeOn", store: SharedState.defaults) private var enabled = false
    @AppStorage(SharedState.Key.affirmationWidgetTheme, store: SharedState.defaults) private var widgetThemeID = "paper"
    @AppStorage(SharedState.Key.affirmationWidgetBackgroundColor, store: SharedState.defaults) private var widgetBackgroundHex = ""
    @AppStorage(SharedState.Key.affirmationWidgetTextColor, store: SharedState.defaults) private var widgetTextHex = "33261A"
    @AppStorage(SharedState.Key.affirmationWidgetFont, store: SharedState.defaults) private var widgetFontName = "Manrope"
    @State private var reminderTimes = [AffirmationNudge.defaultMinutes]
    @State private var reminderDays = Array(1...7)
    @State private var notifDenied = false
    @State private var showingWidgetTheme = false
    @State private var showingBackgroundColor = false
    @State private var showingTextColor = false
    @State private var showingWidgetFont = false

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
                            card {
                                VStack(spacing: 12) {
                                    Button { showingWidgetTheme = true } label: {
                                        HStack(spacing: 12) {
                                            PageThemeBackground(theme: PageTheme.from(widgetThemeID))
                                                .frame(width: 56, height: 44)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(Palette.ink.opacity(0.22), lineWidth: 1))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(loc: "Page theme")
                                                    .font(Fonts.ui(14, .bold)).foregroundStyle(Palette.ink)
                                                Text(loc: PageTheme.from(widgetThemeID).label)
                                                    .font(Fonts.ui(12, .medium)).foregroundStyle(Palette.inkSofter)
                                            }
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.forward")
                                                .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkSofter)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    HStack(spacing: 12) {
                                        widgetColorButton(title: "Background color", hex: effectiveBackgroundHex) {
                                            showingBackgroundColor = true
                                        }
                                        widgetColorButton(title: "Text color", hex: widgetTextHex) {
                                            showingTextColor = true
                                        }
                                    }

                                    Button { showingWidgetFont = true } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "textformat")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Palette.ink)
                                                .frame(width: 32, height: 32)
                                                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 9))
                                            Text(loc: "Font").font(Fonts.ui(14, .bold)).foregroundStyle(Palette.ink)
                                            Spacer()
                                            Text(widgetFontName).font(Fonts.ui(12, .medium)).foregroundStyle(Palette.inkSofter)
                                            Image(systemName: "chevron.forward")
                                                .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkSofter)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .capWidth(Metrics.maxContentWidth)
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingWidgetTheme, onDismiss: reloadWidgetStyle) {
            ThemePickerSheet(selection: widgetThemeSelection, title: "Page theme", confirmSelection: true)
        }
        .sheet(isPresented: $showingBackgroundColor, onDismiss: reloadWidgetStyle) {
            WidgetColorPickerSheet(title: "Background color", hex: backgroundColorBinding)
        }
        .sheet(isPresented: $showingTextColor, onDismiss: reloadWidgetStyle) {
            WidgetColorPickerSheet(title: "Text color", hex: $widgetTextHex)
        }
        .sheet(isPresented: $showingWidgetFont, onDismiss: reloadWidgetStyle) {
            WidgetFontPickerSheet(selection: $widgetFontName)
        }
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

    private var widgetThemeSelection: Binding<PageTheme> {
        Binding(
            get: { PageTheme.from(widgetThemeID) },
            set: { theme in
                widgetThemeID = theme.rawValue
                widgetBackgroundHex = ""
                SharedState.affirmationWidgetTheme = theme.rawValue
                SharedState.affirmationWidgetBackgroundColor = nil
            }
        )
    }

    private var effectiveBackgroundHex: String {
        widgetBackgroundHex.isEmpty ? colorHex(PageTheme.from(widgetThemeID).baseColor) : widgetBackgroundHex
    }

    private var backgroundColorBinding: Binding<String> {
        Binding(
            get: { effectiveBackgroundHex },
            set: { widgetBackgroundHex = $0 }
        )
    }

    private func widgetColorButton(title: String, hex: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(Palette.ink.opacity(0.35), lineWidth: 1))
                Text(loc: title).font(Fonts.ui(11.5, .semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reloadWidgetStyle() {
        // Each setting is persisted by its AppStorage binding as it changes. Writing all four
        // values here can write stale values captured by the parent view when a sheet closes.
        SharedState.defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func colorHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "%02X%02X%02X", Int((red * 255).rounded()),
                      Int((green * 255).rounded()), Int((blue * 255).rounded()))
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
            AmberToggle(isOn: $enabled)       // reminders are free; the widget section stays Premium
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

private struct WidgetColorPickerSheet: View {
    let title: String
    @Binding var hex: String
    @Environment(\.dismiss) private var dismiss
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LibraryHeader(title: title, onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    InlineJournalColorPicker(color: UIColor(Color(hex: hex)), onChange: { hex = Self.hex($0) })
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(EditorToolbar.textColors, id: \.self) { color in
                            Button { hex = color } label: {
                                Circle().fill(Color(hex: color))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().strokeBorder(Palette.ink,
                                        lineWidth: hex.caseInsensitiveCompare(color) == .orderedSame ? 2.5 : 0.6))
                                    .overlay {
                                        if hex.caseInsensitiveCompare(color) == .orderedSame {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .black))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(Text(loc: title) + Text(" #" + color))
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .background(PaperBackground())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private static func hex(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "%02X%02X%02X", Int((red * 255).rounded()),
                      Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}

private struct WidgetFontPickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LibraryHeader(title: "Font", onBack: { dismiss() })
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(FontChoice.allCases) { choice in
                        let active = selection == choice.rawValue
                        Button {
                            selection = choice.rawValue
                            dismiss()
                        } label: {
                            Text(choice.rawValue)
                                .font(Font(choice.uiFont(size: 16)))
                                .foregroundStyle(active ? .white : Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(active ? Palette.amber : Palette.cream,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(active ? Palette.ink : Palette.outlineSoft,
                                                  lineWidth: active ? 2 : 1.2))
                        }
                        .buttonStyle(PressableStyle(scale: 0.97))
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .background(PaperBackground())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
