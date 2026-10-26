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

/// Pick a month's cover: automatic, one of the month's photos (or any from the camera roll), or a
/// page theme's cloth. The book previews live as choices change.
struct CoverEditorSheet: View {
    let book: MonthBook
    @Environment(CoverStore.self) private var covers
    @Environment(\.dismiss) private var dismiss

    private enum Mode: Hashable { case auto, photo, theme }

    @State private var mode: Mode = .auto
    @State private var theme: PageTheme = .paper
    @State private var photo: UIImage?
    @State private var monthPhotos: [UIImage] = []
    @State private var pickerItem: PhotosPickerItem?

    init(book: MonthBook) { self.book = book }

    private var previewLook: CoverLook {
        switch mode {
        case .auto:
            return CoverStore.autoLook(for: book)
        case .theme:
            let style = theme.cover
            return CoverLook(photo: nil, color: style.color, ink: style.ink)
        case .photo:
            if let photo { return CoverLook(photo: photo, color: Palette.ink, ink: .white) }
            return CoverStore.autoLook(for: book)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Text("Cancel").font(Fonts.ui(15, .bold)).foregroundStyle(Palette.inkSoft).frame(minHeight: 44)
                }
                Spacer()
                Text("Cover").font(Fonts.display(17, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Button { save() } label: {
                    Text("Save").font(Fonts.ui(15, .heavy)).foregroundStyle(Palette.amberDeep).frame(minHeight: 44)
                }
                .disabled(mode == .photo && photo == nil)
            }
            .padding(.horizontal, 20).padding(.top, 8)

            MonthBookCover(book: book, width: 150, lookOverride: previewLook)
                .padding(.top, 16)
                .animation(Motion.snappy, value: mode)

            Picker(selection: $mode) {
                Text("Auto").tag(Mode.auto)
                Text("Photo").tag(Mode.photo)
                Text("Theme").tag(Mode.theme)
            } label: {
                Text("Cover")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20).padding(.top, 22)

            ScrollView {
                Group {
                    switch mode {
                    case .auto: autoPane
                    case .photo: photoPane
                    case .theme: themePane
                    }
                }
                .padding(20)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .task { load() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = image
                }
            }
        }
    }

    private var autoPane: some View {
        Text("Made from your month: its newest photo, or the page theme you used most.")
            .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoPane: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 20, weight: .semibold))
                    Text("Camera roll").font(Fonts.ui(12, .heavy))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
            }
            ForEach(Array(monthPhotos.enumerated()), id: \.offset) { _, image in
                Button { photo = image } label: {
                    Color.clear
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .overlay { Image(uiImage: image).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(photo === image ? Palette.amber : Palette.outlineSoft,
                                          lineWidth: photo === image ? 3 : 1.5))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var themePane: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
            ForEach(PageTheme.allCases) { t in
                Button { theme = t } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(t.cover.color)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(theme == t ? Palette.amber : Palette.ink, lineWidth: theme == t ? 3 : 2))
                        Text(loc: t.label).font(Fonts.ui(11, .bold)).foregroundStyle(Palette.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func load() {
        monthPhotos = book.photos()
        switch covers.choice(year: book.year, month: book.month) {
        case .auto:
            mode = .auto
        case .theme(let id):
            mode = .theme
            theme = PageTheme.from(id)
        case .photo:
            mode = .photo
            photo = covers.look(for: book).photo
        }
        if mode != .theme { theme = book.theme }
    }

    private func save() {
        switch mode {
        case .auto: covers.setAuto(year: book.year, month: book.month)
        case .theme: covers.setTheme(theme, year: book.year, month: book.month)
        case .photo:
            guard let photo else { return }
            covers.setPhoto(photo, year: book.year, month: book.month)
        }
        Haptics.success()
        dismiss()
    }
}
