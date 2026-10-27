import SwiftUI
import PhotosUI

/// What a month book's cover looks like: a photo, or a cloth colour with the ink that reads on it.
struct CoverLook {
    var photo: UIImage?
    var color: Color
    var ink: Color

    /// The colour the book frames the page in while writing — a photo cover can't frame a page,
    /// so it falls back to a leather brown.
    var frameColor: Color { photo == nil ? color : Color(hex: "4A3626") }
    var frameInk: Color { photo == nil ? ink : Color(hex: "FFF7EA") }
}

/// Remembers each month's chosen cover. Covers are a presentation choice, not journal content,
/// so they live beside the store rather than in it: the choice in UserDefaults, a chosen photo
/// as a JPEG in Application Support. A month with no choice gets an automatic cover.
@MainActor
@Observable
final class CoverStore {
    enum Choice: Codable, Equatable {
        case auto
        case theme(String)          // PageTheme raw value
        case photo                  // the JPEG saved under the month's key
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
            return CoverLook(photo: nil, color: style.color, ink: style.ink)
        case .photo:
            if let photo = photo(year: book.year, month: book.month) {
                return CoverLook(photo: photo, color: Palette.ink, ink: .white)
            }
            return Self.autoLook(for: book)
        case .auto:
            return Self.autoLook(for: book)
        }
    }

    /// The month's newest photo if it has one, else its most-used page theme.
    static func autoLook(for book: MonthBook) -> CoverLook {
        if let photo = book.coverPhoto { return CoverLook(photo: photo, color: Palette.ink, ink: .white) }
        let style = book.theme.cover
        return CoverLook(photo: nil, color: style.color, ink: style.ink)
    }

    func setAuto(year: Int, month: Int) {
        let key = Self.key(year: year, month: month)
        removePhoto(key)
        choices[key] = nil
        persist()
    }

    func setTheme(_ theme: PageTheme, year: Int, month: Int) {
        let key = Self.key(year: year, month: month)
        removePhoto(key)
        choices[key] = .theme(theme.rawValue)
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

/// Pick a month's cover — every option on one screen: automatic, a photo (the month's own or
/// one from the camera roll), or a page theme's cloth. The book previews the choice live; the
/// tick saves it, the cross leaves the cover as it was.
struct CoverEditorSheet: View {
    let book: MonthBook
    @Environment(CoverStore.self) private var covers
    @Environment(\.dismiss) private var dismiss

    private enum Choice: Equatable {
        case auto
        case photo(UIImage)
        case theme(PageTheme)

        static func == (a: Choice, b: Choice) -> Bool {
            switch (a, b) {
            case (.auto, .auto): return true
            case (.photo(let x), .photo(let y)): return x === y
            case (.theme(let x), .theme(let y)): return x == y
            default: return false
            }
        }
    }

    @State private var choice: Choice = .auto
    @State private var photos: [UIImage] = []
    @State private var pickerItem: PhotosPickerItem?

    init(book: MonthBook) { self.book = book }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    private var previewLook: CoverLook {
        switch choice {
        case .auto:
            return CoverStore.autoLook(for: book)
        case .photo(let image):
            return CoverLook(photo: image, color: Palette.ink, ink: .white)
        case .theme(let theme):
            let style = theme.cover
            return CoverLook(photo: nil, color: style.color, ink: style.ink)
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

                    autoOption.padding(.top, 24)

                    Eyebrow(text: "Photo", color: Palette.inkSoft).padding(.top, 24)
                    LazyVGrid(columns: columns, spacing: 12) {
                        cameraRollTile
                        ForEach(Array(photos.enumerated()), id: \.offset) { _, image in
                            photoTile(image)
                        }
                    }
                    .padding(.top, 10)

                    Eyebrow(text: "Theme", color: Palette.inkSoft).padding(.top, 24)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(PageTheme.allCases) { theme in themeTile(theme) }
                    }
                    .padding(.top, 10)
                }
                .padding(EdgeInsets(top: 4, leading: 20, bottom: 30, trailing: 20))
            }
        }
        .background(Palette.cream.ignoresSafeArea())
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
        HStack(spacing: 12) {
            IconTileButton(icon: "xmark", size: 38, iconSize: 13) { dismiss() }
            Text("Cover").font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            IconTileButton(icon: "checkmark", size: 38, iconSize: 14) { save() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // Automatic — a card, coral with an ink outline when chosen.
    private var autoOption: some View {
        let selected = choice == .auto
        return Button { pick(.auto) } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(selected ? Palette.onAmber : Palette.iconTile,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto").font(Fonts.ui(14.5, .heavy)).foregroundStyle(Palette.ink)
                    Text("Made from your month: its newest photo, or the page theme you used most.")
                        .font(Fonts.ui(12.5, .semibold))
                        .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(selected ? Palette.amber : Palette.paper,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Palette.ink : Palette.outlineSoft, lineWidth: selected ? 2 : 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private var cameraRollTile: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle").font(.system(size: 20, weight: .semibold))
                Text("Camera roll").font(Fonts.ui(12, .heavy))
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }

    private func photoTile(_ image: UIImage) -> some View {
        let selected = choice == .photo(image)
        return Button { pick(.photo(image)) } label: {
            Color.clear
                .frame(height: 128)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .selectedRing(selected)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }

    private func themeTile(_ theme: PageTheme) -> some View {
        let selected = choice == .theme(theme)
        let style = theme.cover
        return Button { pick(.theme(theme)) } label: {
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(style.color)
                    .frame(height: 108)
                    .selectedRing(selected)
                Text(loc: theme.label)
                    .font(Fonts.ui(12, selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.7)
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
            choice = .auto
        case .theme(let id):
            choice = .theme(PageTheme.from(id))
        case .photo:
            if let saved = covers.look(for: book).photo {
                found.insert(saved, at: 0)
                choice = .photo(saved)
            }
        }
        photos = found
    }

    private func save() {
        switch choice {
        case .auto: covers.setAuto(year: book.year, month: book.month)
        case .theme(let theme): covers.setTheme(theme, year: book.year, month: book.month)
        case .photo(let image): covers.setPhoto(image, year: book.year, month: book.month)
        }
        Haptics.success()
        dismiss()
    }
}

private extension View {
    /// A chosen tile: coral ring inside an ink outline, with a tick in the corner.
    func selectedRing(_ selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return self
            .overlay(shape.strokeBorder(selected ? Palette.ink : Palette.outlineSoft, lineWidth: selected ? 5 : 1.5))
            .overlay(shape.inset(by: 2).strokeBorder(selected ? Palette.amber : .clear, lineWidth: 2.5))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Palette.ink)
                        .frame(width: 22, height: 22)
                        .background(Palette.amber, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1.5))
                        .padding(7)
                }
            }
    }
}
