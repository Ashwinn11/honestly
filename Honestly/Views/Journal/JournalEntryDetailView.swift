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
                .contentColumn()
            }
        }
    }

    private var nav: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").headerCircle()
            }
            .buttonStyle(.plain)
            Spacer()
            Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year().locale(appLocale)))
                .font(AppFont.bodyBold(18))
                .foregroundStyle(Theme.ink)
            Spacer()
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up").headerCircle()
            }
        }
    }

    private var meta: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("\(entry.date.formatted(.dateTime.weekday(.wide).locale(appLocale)).uppercased()) · \(entry.date.formatted(.dateTime.month(.wide).day().locale(appLocale)))", size: 18)
                Text(String(format: L("%@ · %lld words"), entry.date.formatted(.dateTime.hour().minute().locale(appLocale)), entry.wordCount))
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
                IconEyebrow(icon: "book.fill", text: "THIS MORNING", size: 17)
                Text(entry.content.isEmpty ? "—" : entry.content)
                    .font(AppFont.body(17))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(14)
            }
            .padding(20)
        }
        .appCardStyle(fill: Theme.card)
    }

    private var gratitudeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconEyebrow(icon: "heart.fill", text: "GRATEFUL FOR", size: 17)
            Text(entry.gratitude.isEmpty ? "—" : entry.gratitude)
                .font(AppFont.body(17))
                .foregroundStyle(Theme.ink)
                .lineSpacing(8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(fill: Theme.gratitude)
    }

    private var shareText: String {
        """
        \(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(appLocale)))

        \(L("This morning:"))
        \(entry.content)

        \(L("Grateful for:"))
        \(entry.gratitude)

        \(L("— written with Honestly"))
        """
    }
}
