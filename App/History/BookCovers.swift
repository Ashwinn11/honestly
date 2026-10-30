import SwiftUI
import PhotosUI

/// What a month book's cover looks like: one of the cover designs, a photo, or (for covers chosen
/// before designs existed) a plain cloth colour.
struct CoverLook {
    var design: CoverDesign? = nil
    var photo: UIImage? = nil
    var color: Color
    var ink: Color

    init(design: CoverDesign) {
        self.design = design
        self.color = design.base
        self.ink = design.ink
    }

    init(photo: UIImage) {
        self.photo = photo
        self.color = Palette.ink
        self.ink = .white
    }

    init(color: Color, ink: Color) {
        self.color = color
        self.ink = ink
    }

    /// The colour the book frames the page in — a photo cover can't frame a page, so it falls
    /// back to a leather brown.
    var frameColor: Color { photo == nil ? color : Palette.leather }
}

/// Remembers each month's chosen cover. Covers are a presentation choice, not journal content,
/// so they live beside the store rather than in it: the choice in UserDefaults, a chosen photo
/// as a JPEG in Application Support. A month with no choice wears its own design
/// (`CoverDesign.forMonth`), so every month looks different until someone changes it.
@MainActor
@Observable
final class CoverStore {
    enum Choice: Codable, Equatable {
        case auto
        case theme(String)          // PageTheme raw value — covers chosen before designs existed
        case photo                  // the JPEG saved under the month's key
        case design(String)         // CoverDesign raw value
    }

    private(set) var choices: [String: Choice] = [:]
    private var photoCache: [String: UIImage] = [:]
    private var revision = 0         // bumps when a photo changes, so covers re-read it

    private static let defaultsKey = "monthCoverChoices"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([String: Choice].self, from: data) {
            choices = saved
        }
    }

    static func key(year: Int, month: Int) -> String { String(format: "%04d-%02d", year, month) }

    func choice(year: Int, month: Int) -> Choice { choices[Self.key(year: year, month: month)] ?? .auto }

    /// The cover a book shows right now.
    func look(for book: MonthBook) -> CoverLook {
        _ = revision
        switch choice(year: book.year, month: book.month) {
        case .theme(let id):
            let style = PageTheme.from(id).cover
            return CoverLook(color: style.color, ink: style.ink)
        case .photo:
            if let photo = photo(year: book.year, month: book.month) { return CoverLook(photo: photo) }
            return Self.autoLook(for: book)
        case .design(let id):
            return CoverLook(design: CoverDesign(rawValue: id) ?? .forMonth(year: book.year, month: book.month))
        case .auto:
            return Self.autoLook(for: book)
        }
    }

    /// The month's own design.
    static func autoLook(for book: MonthBook) -> CoverLook {
        CoverLook(design: .forMonth(year: book.year, month: book.month))
    }

    func setDesign(_ design: CoverDesign, year: Int, month: Int) {
        let key = Self.key(year: year, month: month)
        removePhoto(key)
        // The month's own design needs no saved choice — it's what an unset month shows anyway.
        choices[key] = design == .forMonth(year: year, month: month) ? nil : .design(design.rawValue)
        persist()
    }

    func setPhoto(_ image: UIImage, year: Int, month: Int) {
        let key = Self.key(year: year, month: month)
        let scaled = image.downscaledForJournal(maxDimension: 1100, quality: 0.85)
        guard let data = scaled.jpegData(compressionQuality: 0.85) else { return }
        do {
            try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            try data.write(to: Self.file(key), options: .atomic)
        } catch { return }
        photoCache[key] = scaled
        choices[key] = .photo
        revision += 1
        persist()
    }

    /// Forget every cover — part of "Delete all data".
    func reset() {
        try? FileManager.default.removeItem(at: Self.folder)
        photoCache = [:]
        choices = [:]
        revision += 1
        persist()
    }

    private func photo(year: Int, month: Int) -> UIImage? {
        let key = Self.key(year: year, month: month)
        if let cached = photoCache[key] { return cached }
        guard let image = UIImage(contentsOfFile: Self.file(key).path) else { return nil }
        photoCache[key] = image
        return image
    }

    private func removePhoto(_ key: String) {
        try? FileManager.default.removeItem(at: Self.file(key))
        photoCache[key] = nil
        revision += 1
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(choices) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private static var folder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Covers", isDirectory: true)
    }
    private static func file(_ key: String) -> URL { folder.appendingPathComponent("\(key).jpg") }
}

extension MonthBook {
    /// The book a date falls in, built from the store's pages.
    @MainActor
    static func containing(_ date: Date, in store: JournalStore) -> MonthBook {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month], from: date)
        let now = cal.dateComponents([.year, .month], from: Date())
        let year = c.year ?? 0, month = c.month ?? 0
        return MonthBook(year: year, month: month,
                         entries: store.entries(inYear: year, month: month).sorted { $0.date < $1.date },
                         isCurrent: c.year == now.year && c.month == now.month)
    }

    /// Full-size photos from the month's pages, newest first — choices for a photo cover.
    func photos(limit: Int = 8) -> [UIImage] {
        var found: [UIImage] = []
        for entry in entries.reversed() {
            guard found.count < limit, let data = entry.richContent,
                  let text = NSAttributedString.from(rtfdData: data) else { continue }
            text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, stop in
                guard let attachment = value as? NSTextAttachment,
                      RichTextFormatting.kind(of: attachment) == .photo,
                      let image = RichTextFormatting.attachmentImage(attachment) else { return }
                found.append(image)
                if found.count >= limit { stop.pointee = true }
            }
        }
        return found
    }
}

// MARK: - Cover editor

/// Pick a month's cover: a design (Illustrated, Patterns, Classic) or a photo — the month's own or
/// one from the camera roll. The book previews the choice live; the tick saves it, the cross
/// leaves the cover as it was.
struct CoverEditorSheet: View {
    let book: MonthBook
    @Environment(CoverStore.self) private var covers
    @Environment(PremiumManager.self) private var premium
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private enum Choice: Equatable {
        case design(CoverDesign)
        case photo(UIImage)
        case cloth(PageTheme)       // a plain colour chosen before designs existed

        static func == (a: Choice, b: Choice) -> Bool {
            switch (a, b) {
            case (.design(let x), .design(let y)): return x == y
            case (.photo(let x), .photo(let y)): return x === y
            case (.cloth(let x), .cloth(let y)): return x == y
            default: return false
            }
        }
    }

    private enum Tab: CaseIterable { case illustrated, patterns, classic, photo
        var title: String {
            switch self {
            case .illustrated: "Illustrated"
            case .patterns: "Patterns"
            case .classic: "Classic"
            case .photo: "Photo"
            }
        }
        var icon: String {
            switch self {
            case .illustrated: "paintbrush.pointed"
            case .patterns: "square.grid.3x3"
            case .classic: "book.closed"
            case .photo: "photo"
            }
        }
        var group: CoverDesign.Group? {
            switch self {
            case .illustrated: .illustrated
            case .patterns: .patterns
            case .classic: .classic
            case .photo: nil
            }
        }
    }

    @State private var choice: Choice = .design(.bouquet)
    @State private var tab: Tab = .illustrated
    @State private var photos: [UIImage] = []
    @State private var pickerItem: PhotosPickerItem?

    init(book: MonthBook) { self.book = book }

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    private var previewLook: CoverLook {
        switch choice {
        case .design(let design): CoverLook(design: design)
        case .photo(let image): CoverLook(photo: image)
        case .cloth(let theme): CoverLook(color: theme.cover.color, ink: theme.cover.ink)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonthBookCover(book: book, width: 140, lookOverride: previewLook)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .animation(Motion.snappy, value: choice)

                    tabs.padding(.top, 24)

                    if let group = tab.group {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(CoverDesign.allCases.filter { $0.group == group }) { designTile($0) }
                        }
                        .padding(.top, 16)
                    } else {
                        // The camera roll is its own full-width row, so it never squeezes in among
                        // (or stands alone without) the month's photos.
                        cameraRollRow.padding(.top, 16)
                        if photos.isEmpty {
                            Text(loc: "Photos you add to this month's pages show up here.")
                                .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 14)
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(Array(photos.enumerated()), id: \.offset) { _, image in photoTile(image) }
                            }
                            .padding(.top, 14)
                        }
                    }
                }
                .padding(EdgeInsets(top: 4, leading: 20, bottom: 30, trailing: 20))
            }
        }
        .sheetBackground()
        .paywallCover(isPresented: $showPaywall)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task { load() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photos.insert(image, at: 0)
                    pick(.photo(image))
                }
            }
        }
    }

    private var topBar: some View {
        ScreenHeader(Text("Cover")) {
            IconTileButton.close { dismiss() }
        } trailing: {
            IconTileButton.confirm { save() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // Illustrated, Patterns, Classic, Photo — the shared chip row.
    private var tabs: some View {
        ChipTabs(items: Tab.allCases, selection: $tab, title: \.title, icon: \.icon)
            .padding(.horizontal, -20)          // the row runs edge to edge; its chips keep the margin
    }

    /// Photo covers, and every design but the free five, come with Premium.
    private var coversUnlocked: Bool { premium.allows(.coverDesigns) }

    private func designTile(_ design: CoverDesign) -> some View {
        let selected = choice == .design(design)
        // Browsing is free; the cover already on the book never shows a lock.
        let locked = !coversUnlocked && !design.isFree && !selected
        return Button { if locked { showPaywall = true } else { pick(.design(design)) } } label: {
            VStack(spacing: 6) {
                CoverArt(design: design, month: book.firstOfMonth)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .selectedRing(selected)
                    .overlay(alignment: .topTrailing) {
                        if locked { PremiumLockBadge(size: 17).padding(6) }
                    }
                Text(loc: design.name)
                    .font(Fonts.ui(12, selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityLabel(Text(loc: design.name))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var cameraRollRow: some View {
        if coversUnlocked {
            PhotosPicker(selection: $pickerItem, matching: .images) { cameraRollLabel }
                .buttonStyle(PressableStyle(scale: 0.98))
        } else {
            Button { showPaywall = true } label: { cameraRollLabel }
                .buttonStyle(PressableStyle(scale: 0.98))
        }
    }

    private var cameraRollLabel: some View {
        HStack(spacing: 12) {
            IconTile(size: 38) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: DesignScale.s(15), weight: .bold)).foregroundStyle(Palette.ink)
            }
            Text("Camera roll").font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            if coversUnlocked {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkSofter)
            } else {
                PremiumLockBadge(size: 17)
            }
        }
        .padding(12)
        .outlinedSurface()
        .contentShape(Rectangle())
    }

    private func photoTile(_ image: UIImage) -> some View {
        let selected = choice == .photo(image)
        let locked = !coversUnlocked && !selected
        return Button { if locked { showPaywall = true } else { pick(.photo(image)) } } label: {
            Color.clear
                .aspectRatio(120 / 170, contentMode: .fit)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .selectedRing(selected)
                .overlay(alignment: .topTrailing) {
                    if locked { PremiumLockBadge(size: 17).padding(6) }
                }
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }

    private func pick(_ new: Choice) {
        Haptics.select()
        withAnimation(Motion.snappy) { choice = new }
    }

    private func load() {
        var found = book.photos()
        switch covers.choice(year: book.year, month: book.month) {
        case .auto:
            choice = .design(.forMonth(year: book.year, month: book.month))
        case .design(let id):
            choice = .design(CoverDesign(rawValue: id) ?? .forMonth(year: book.year, month: book.month))
        case .theme(let id):
            choice = .cloth(PageTheme.from(id))
        case .photo:
            if let saved = covers.look(for: book).photo {
                found.insert(saved, at: 0)
                choice = .photo(saved)
                tab = .photo
            }
        }
        if case .design(let design) = choice {
            tab = Tab.allCases.first { $0.group == design.group } ?? .illustrated
        }
        photos = found
    }

    private func save() {
        switch choice {
        case .design(let design): covers.setDesign(design, year: book.year, month: book.month)
        case .photo(let image): covers.setPhoto(image, year: book.year, month: book.month)
        case .cloth: break           // unchanged: keep the cloth it already has
        }
        Haptics.success()
        dismiss()
    }
}
