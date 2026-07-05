import SwiftUI

struct HomeView: View {
    @Environment(JournalStore.self) private var store
    @Environment(AppFlow.self) private var flow
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(PremiumManager.self) private var premium

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                header
                todayCard.padding(.top, 4)
                streakCard.padding(.top, 16)
                affirmationSection.padding(.top, 24)
            }
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loc: HDate.greetingKey(Date())).font(Fonts.display(34, .bold)).foregroundStyle(Palette.ink)
                .fixedSize()
                .underlineSquiggle(Palette.amber, weight: 4.5, height: 10)
            Eyebrow(text: HDate.homeHeader(Date()), color: Palette.inkSoft, tracking: 1.4)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            SoftGlow(color: Palette.sunDisc, opacity: 0.16, size: 240).offset(x: -80, y: -70)
        }
        .padding(.bottom, 22)
    }

    // MARK: This-morning card
    @ViewBuilder private var todayCard: some View {
        if let today = store.todayEntry {
            doneCard(today)
        } else {
            unwrittenCard
        }
    }

    private var unwrittenCard: some View {
        let count = screenTime.selectedCount
        let appsLine: Text = count > 0
            ? Text("\(count) apps stay asleep until you write. A few quiet minutes, just for you.")
            : Text("Your apps stay asleep until you write. A few quiet minutes, just for you.")
        return ZStack(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.16)).frame(width: 120, height: 120).offset(x: 30, y: -30)
            SunMark(size: 50, tint: Color(hex: "FFF4E0")).rotationEffect(.degrees(-8))
                .offset(x: -6, y: 10).floaty(period: 5)
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "This morning", color: .white.opacity(0.92))
                Text("Your page is waiting")
                    .font(Fonts.display(25, .bold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 52)          // clear the floating sun in the corner
                    .padding(.top, 6)
                appsLine
                    .font(Fonts.ui(13.5, .semibold)).foregroundStyle(.white.opacity(0.95))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                CreamButton(title: "Write today's page") { flow.startRitual() }
                    .padding(.top, 18)
            }
        }
        .padding(20)
        .background(Palette.heroGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .tactile(6, cornerRadius: 24)
        .shadow(color: Palette.heroDeep.opacity(0.42), radius: 22, y: 14)
        .staggeredAppear(index: 0)
    }

    private func doneCard(_ entry: JournalEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.25)).frame(width: 120, height: 120).offset(x: 30, y: -34)
            HStack(spacing: 15) {
                MoodFace(mood: entry.moodRaw, size: 44)
                    .frame(width: 60, height: 60)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: "Today · done", color: Palette.ink.opacity(0.85), size: 11)
                    Text("Your apps are awake")
                        .font(Fonts.display(23, .bold)).foregroundStyle(Palette.ink)
                    Group {
                        if premium.isPremium {
                            NavigationLink(value: entry.dayKey) { readTodayLabel }
                        } else {
                            Button { flow.showPaywall() } label: { readTodayLabel }
                        }
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .background(Palette.mood(1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .shadow(color: Color(hex: "3C5A28").opacity(0.4), radius: 20, y: 12)
        .staggeredAppear(index: 0)
    }

    private var readTodayLabel: some View {
        HStack(spacing: 6) {
            Text("Read today's page")
                .font(Fonts.ui(13.5, .heavy)).foregroundStyle(Palette.amberDeep)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.amberDeep)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.amberDeep.opacity(0.4)).frame(height: 2).offset(y: 2)
        }
    }

    // MARK: Streak card
    private var streakCard: some View {
        VStack(spacing: 17) {
            HStack(spacing: 13) {
                IconTile(size: 52, fill: Palette.iconTile, radius: 16) { SunMark(size: 28) }
                HStack(alignment: .center, spacing: 10) {
                    Text("\(monthCount)").font(Fonts.display(30, .heavy)).foregroundStyle(Palette.ink)
                    Text("mornings written\nin \(HDate.monthShort(Date()))")
                        .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSoft).lineSpacing(1)
                }
                Spacer(minLength: 0)
            }
            weeklyGoalRow
        }
        .softCard(padding: 18)
        .staggeredAppear(index: 1)
    }

    private var monthCount: Int {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return store.monthCount(year: c.year ?? 0, month: c.month ?? 0)
    }

    private var morningsThisWeek: Int { store.weekStrip.filter { $0.entry != nil }.count }
    private var weeklyGoalRow: some View {
        let goal = max(SharedState.weeklyGoal, 1)
        let done = morningsThisWeek
        let frac = min(CGFloat(done) / CGFloat(goal), 1)
        return HStack(spacing: 11) {
            Eyebrow(text: "This week", tracking: 1, size: 10.5)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "F2EADB"))
                        .overlay(Capsule().stroke(Palette.ink.opacity(0.14), lineWidth: 1.5))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "FFB067"), Palette.amber],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, g.size.width * frac))
                }
            }
            .frame(height: 8)
            Text(done >= goal ? "Goal met" : "\(done)/\(goal)")
                .font(Fonts.ui(12, .heavy))
                .foregroundStyle(done >= goal ? Palette.success : Palette.inkSoft)
        }
        .padding(.top, 2)
    }


    // MARK: Today's affirmations
    @ViewBuilder private var affirmationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today's affirmations").font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                .fixedSize()
                .underlineSquiggle(Palette.sunDisc, weight: 3.5, height: 8)
                .padding(.bottom, 13)

            if let today = store.todayEntry, !today.gratitudes.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(today.gratitudes.enumerated()), id: \.offset) { i, line in
                        HStack(spacing: 12) {
                            SunMark(size: 22, rays: false)
                            Text(line).font(Fonts.ui(14.5, .semibold)).foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
                        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.5))
                        .staggeredAppear(index: i + 2)
                    }
                }
            } else {
                emptyAffirmations
            }
        }
    }
    private var emptyAffirmations: some View {
        VStack(spacing: 8) {
            SunMark(size: 34, muted: true)
            Text("Your affirmations will land here\nonce you've written this morning.")
                .font(Fonts.ui(13.5, .semibold)).foregroundStyle(Palette.inkSofter)
                .multilineTextAlignment(.center).lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
