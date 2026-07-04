import SwiftUI

/// The native language menu, in two dress-ups. Both open the system `Menu` (a real native picker),
/// mark the current language with a checkmark, and switch live via `LocalizationManager.select`.
private struct LanguageMenu<Trigger: View>: View {
    @Environment(LocalizationManager.self) private var l10n
    @ViewBuilder var label: () -> Trigger

    var body: some View {
        Menu {
            ForEach(LocalizationManager.supported) { lang in
                Button {
                    l10n.select(lang)
                } label: {
                    if lang.code == l10n.code { Label(lang.name, systemImage: "checkmark") }
                    else { Text(lang.name) }
                }
            }
        } label: {
            label()
        }
        .tint(Palette.ink)   // keep the menu off the system accent
    }
}

/// Pill-shaped picker for the top of onboarding o1.
struct LanguagePickerPill: View {
    @Environment(LocalizationManager.self) private var l10n
    var body: some View {
        LanguageMenu {
            HStack(spacing: 7) {
                Image(systemName: "globe").font(.system(size: DesignScale.s(13), weight: .bold))
                Text(l10n.current.name).font(Fonts.ui(13.5, .heavy))
                Image(systemName: "chevron.down").font(.system(size: DesignScale.s(9), weight: .heavy))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 15).padding(.vertical, 9)
            .background(Palette.cream, in: Capsule())
            .overlay(Capsule().stroke(Palette.ink, lineWidth: 2))
        }
    }
}

/// Settings-row picker for the profile "Language" row.
struct LanguagePickerRow: View {
    @Environment(LocalizationManager.self) private var l10n
    var body: some View {
        LanguageMenu {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Language").font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                    Text("Choose your app language")
                        .font(Fonts.ui(12, .medium)).foregroundStyle(Palette.inkSofter)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 8)
                Text(l10n.current.name).font(Fonts.ui(14, .bold)).foregroundStyle(Palette.amberDeep)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.hairline)
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
        }
    }
}
