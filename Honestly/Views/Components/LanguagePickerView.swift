import SwiftUI

/// Full-language chooser. Selecting a row switches the app language live.
struct LanguagePickerView: View {
    @EnvironmentObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.pageBackground
            VStack(spacing: 0) {
                HStack {
                    Eyebrow("choose your", size: 18)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").headerCircle()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                HStack {
                    Text("Language")
                        .font(AppFont.title(30))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(AppLanguage.allCases) { lang in
                            row(lang)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentColumn()
                }
            }
        }
    }

    private func row(_ lang: AppLanguage) -> some View {
        let isSelected = localization.language == lang
        return Button {
            localization.setLanguage(lang)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(lang.flag)
                    .font(.system(size: 28))
                Text(lang.nativeName)
                    .font(AppFont.bodyBold(17))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.orange)
                }
            }
            .padding(16)
            .appCardStyle(fill: isSelected ? Theme.orange.opacity(0.12) : Theme.card,
                          borderColor: isSelected ? Theme.orange : Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

/// Compact pill (globe + current language) used in onboarding's top corner.
struct LanguagePill: View {
    @EnvironmentObject var localization: LocalizationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(localization.language.nativeName)
            }
            .font(AppFont.bodySemibold(15))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.card).clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.ink, lineWidth: Theme.borderWidth))
        }
        .buttonStyle(.plain)
    }
}
