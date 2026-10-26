import SwiftUI
import FamilyControls

struct HomeView: View {
    @Environment(JournalStore.self) private var store
    @Environment(AppFlow.self) private var flow
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(PremiumManager.self) private var premium
    @Environment(AffirmationList.self) private var affirmations
    @Environment(\.openURL) private var openURL
    @State private var showBlockingPicker = false
    @State private var showAccessHelp = false

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                header
                todayCard.padding(.top, 4)
                streakCard.padding(.top, 16)
                affirmationSection.padding(.top, 24)
            }
        }
        .familyActivityPicker(isPresented: $showBlockingPicker, selection: Binding(
            get: { screenTime.selection }, set: { screenTime.selection = $0 }))
        .alert("Screen Time access is off", isPresented: $showAccessHelp) {
            Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(loc: "Allow Screen Time access, then choose the apps you want to hold.")
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loc: HDate.greetingKey(Date())).font(Fonts.display(34, .bold)).foregroundStyle(Palette.ink)
                .fixedSize()
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
        let appsLine = Text(loc: screenTime.blockingPresentation.isHoldingApps
            ? "Your apps can wait. This moment is yours."
            : "A few honest lines. A little space for yourself.")
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
                if !screenTime.authorized || !screenTime.hasSelection {
                    Button {
                        if !premium.isPremium { flow.showPaywall(); return }
                        Task {
                            if await screenTime.ensureAuthorizedForPicker() { showBlockingPicker = true }
                            else { showAccessHelp = true }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                            Text(loc: screenTime.authorized ? "Choose apps" : "Approve Screen Time")
                            Image(systemName: "chevron.forward")
                        }
                        .font(Fonts.ui(12.5, .bold)).foregroundStyle(.white)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                CreamButton(title: "Write today's page") { flow.startRitual() }
                    .padding(.top, 18)
            }
        }
        .padding(20)
        .background(Palette.heroGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
        .tactile(6, cornerRadius: 24)
        .shadow(color: Palette.heroDeep.opacity(0.42), radius: 22, y: 14)
        .staggeredAppear(index: 0)
    }

    private func doneCard(_ entry: JournalEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.25)).frame(width: 120, height: 120).offset(x: 30, y: -34)
            MoodFace(mood: entry.moodRaw, size: 44)
                .frame(width: 60, height: 60)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
                .padding(.top, 4)
                .padding(.trailing, 4)

            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Today · done", color: Palette.ink.opacity(0.85), size: 11)
                Text(loc: screenTime.blockingPresentation.isScheduledNow
                     ? "Your apps are awake" : "You made time for yourself.")
                    .font(Fonts.display(23, .bold)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 60)
                    .padding(.top, 6)
                // Today's page opens inside this month's book — free to read, like the rest of
                // the current month.
                NavigationLink(value: MonthBookRoute(entry: entry)) { readTodayLabel }
                .buttonStyle(TactileButtonStyle(fill: AnyShapeStyle(Palette.onAmber),
                                                cornerRadius: DesignScale.s(16), ledge: 4, bordered: true))
                .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Palette.mood(1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
        .shadow(color: Color(hex: "3C5A28").opacity(0.4), radius: 20, y: 12)
        .staggeredAppear(index: 0)
    }

    private var readTodayLabel: some View {
        HStack(spacing: 9) {
            Text("Read today's page")
                .font(Fonts.ui(16, .heavy)).foregroundStyle(Palette.amberDeep)
            Image(systemName: "arrow.forward")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.amberDeep)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignScale.s(15))
    }

    // MARK: Streak card
    private var streakCard: some View {
        VStack(spacing: 17) {
            HStack(spacing: 13) {
                IconTile(size: 52, fill: Palette.iconTile, radius: 16) { SunMark(size: 28) }
                HStack(alignment: .center, spacing: 10) {
                    Text("\(monthCount)").font(Fonts.display(30, .heavy)).foregroundStyle(Palette.ink)
                    Text("Mornings in \(HDate.monthShort(Date()))")
                        .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.14), lineWidth: 1.5))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "FFB067"), Palette.amber],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, g.size.width * frac))
                }
            }
            .frame(height: 8)
            // Literal `Text`, not `Text(loc:)`: the compiler only extracts (and localizes) keys
            // from direct literals — a `String` ternary would look up "2/5" instead of "%lld/%lld".
            (done >= goal ? Text("Goal met") : Text("\(done)/\(goal)"))
                .font(Fonts.ui(12, .heavy))
                .foregroundStyle(done >= goal ? Palette.success : Palette.inkSoft)
        }
        .padding(.top, 2)
    }


    // MARK: Today's affirmation — one line a day from the picked rotation (see `Affirmations`),
    // the same one the widget and the daily notification carry. Shown from midnight, written or not.
    private var affirmationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today's affirmation").font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                .fixedSize()
            .padding(.bottom, 13)

            NavigationLink {
                AffirmationReaderScreen(startingLine: affirmations.today(premium: premium.isPremium))
                    .toolbar(.hidden, for: .navigationBar)
            } label: {
                HStack(spacing: 12) {
                    SunMark(size: 22, rays: false)
                    Affirmations.text(affirmations.today(premium: premium.isPremium))
                        .font(Fonts.ui(14.5, .semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.inkSofter)
                }
                .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.outlineSoft, lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle(scale: 0.99))
            .accessibilityHint(Text(loc: "Read and browse affirmations"))
            .staggeredAppear(index: 2)
        }
    }
}
