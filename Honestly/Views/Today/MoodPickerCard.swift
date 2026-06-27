import SwiftUI

/// "how's the inside weather today?" — tapping a mood begins the ritual.
struct MoodPickerCard: View {
    let onPick: (Mood) -> Void

    var body: some View {
        AppCard(padding: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("how's the inside\nweather today?")
                    .font(AppFont.cardTitle())
                    .foregroundStyle(Theme.ink)

                Eyebrow("tap a mood to begin writing", size: 18)

                Divider().overlay(Theme.inkGhost)

                HStack(spacing: 8) {
                    ForEach(Mood.allCases) { mood in
                        Button { onPick(mood) } label: {
                            VStack(spacing: 8) {
                                MoodFace(mood: mood, size: 54)
                                Text(mood.displayName)
                                    .font(AppFont.caption(13))
                                    .foregroundStyle(Theme.ink)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
