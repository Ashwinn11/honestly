import SwiftUI

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.pageBackground
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    nav
                    meta
                    morningCard
                    gratitudeCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
            }
        }
    }

    private var nav: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(Theme.card).clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(AppFont.bodyBold(18))
                .foregroundStyle(Theme.ink)
            Spacer()
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(Theme.card).clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
            }
        }
    }

    private var meta: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("\(entry.date.formatted(.dateTime.weekday(.wide)).uppercased()) · \(entry.date.formatted(.dateTime.month(.wide).day()))", size: 18)
                Text("\(entry.date.formatted(.dateTime.hour().minute())) · \(entry.wordCount) words")
                    .font(AppFont.caption(14))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            MoodFace(mood: entry.mood, size: 56)
        }
    }

    private var morningCard: some View {
        ZStack(alignment: .topLeading) {
            LinedPaper()
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("📖 THIS MORNING", size: 17)
                Text(entry.content.isEmpty ? "—" : entry.content)
                    .font(AppFont.body(17))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(14)
            }
            .padding(20)
            PlantView(stage: .sprout, size: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(8)
                .allowsHitTesting(false)
        }
        .appCardStyle(fill: Theme.card)
    }

    private var gratitudeCard: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("❤️ GRATEFUL FOR", size: 17)
                Text(entry.gratitude.isEmpty ? "—" : entry.gratitude)
                    .font(AppFont.body(17))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(8)
            }
            .padding(20)
            Mascot(kind: .flower, size: 42)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(8)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(fill: Theme.gratitude)
    }

    private var shareText: String {
        """
        \(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))

        This morning:
        \(entry.content)

        Grateful for:
        \(entry.gratitude)

        — written with Honestly
        """
    }
}
