import SwiftUI
import SwiftData

struct BibleView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case today = "Today", library = "Library", favorites = "Favorites", history = "History"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Query private var favorites: [FavoriteVerse]
    @Query private var habits: [Habit]
    @Query private var habitLogs: [HabitLog]

    @State private var tab: Tab = .today
    @State private var theme = "All"
    @State private var search = ""

    private var favoriteRefs: Set<String> { Set(favorites.map(\.reference)) }
    private var bibleHabit: Habit? { habits.first { $0.autoKey == "bible" } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .today: todayView
                case .library: libraryView
                case .favorites: favoritesView
                case .history: historyView
                }
                Text("Scripture: King James Version (public domain). Reflections are original short thoughts, not Scripture.")
                    .font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Bible")
    }

    // MARK: Today

    private var todayView: some View {
        let v = BibleData.verse(on: Date())
        let read = bibleHabit.map { h in habitLogs.contains { $0.habitID == h.id && $0.day == Date().startOfDay } } ?? false
        return VStack(alignment: .leading, spacing: 16) {
            VerseCard(verse: v, large: true, isFavorite: favoriteRefs.contains(v.reference)) { toggleFavorite(v) }
            VStack(alignment: .leading, spacing: 8) {
                Label("Reflection", systemImage: "leaf").font(.headline).foregroundStyle(Theme.accentText)
                Text(v.reflection).font(.system(.body, design: .default)).foregroundStyle(Theme.text)
            }
            .card()
            if let h = bibleHabit {
                Button {
                    Haptics.success()
                    context.toggleHabit(h, on: Date(), logs: habitLogs)
                } label: {
                    Label(read ? "Read today ✓" : "Mark as read", systemImage: read ? "checkmark.circle.fill" : "book")
                }
                .buttonStyle(read ? AnyButtonStyle(SoftButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
            }
            ShareLink(item: "“\(v.text)” — \(v.reference) (KJV)") {
                Label("Share verse", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SoftButtonStyle())
        }
    }

    // MARK: Library

    private var libraryView: some View {
        let themes = ["All"] + BibleData.themes
        let list = BibleData.verses.filter { v in
            (theme == "All" || v.theme == theme) &&
            (search.isEmpty || v.text.localizedCaseInsensitiveContains(search) || v.reference.localizedCaseInsensitiveContains(search))
        }
        return VStack(alignment: .leading, spacing: 14) {
            TextField("Search verses", text: $search)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(themes, id: \.self) { t in Chip(title: t, selected: theme == t) { theme = t } }
                }
            }
            ForEach(list) { v in
                VerseCard(verse: v, large: false, isFavorite: favoriteRefs.contains(v.reference)) { toggleFavorite(v) }
            }
            if list.isEmpty { Text("No verses match.").foregroundStyle(Theme.textSecondary) }
        }
    }

    // MARK: Favorites

    private var favoritesView: some View {
        let list = favorites.sorted { $0.savedAt > $1.savedAt }.compactMap { BibleData.verse(for: $0.reference) }
        return VStack(alignment: .leading, spacing: 14) {
            if list.isEmpty {
                EmptyState(icon: "heart", title: "No favorites yet", message: "Tap the heart on any verse to keep it here.")
            }
            ForEach(list) { v in
                VerseCard(verse: v, large: false, isFavorite: true) { toggleFavorite(v) }
            }
        }
    }

    // MARK: History

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your verses from the past two weeks").font(.footnote).foregroundStyle(Theme.textSecondary)
            ForEach(Date.lastDays(14).reversed(), id: \.self) { d in
                let v = BibleData.verse(on: d)
                VStack(alignment: .leading, spacing: 6) {
                    Text(d.isToday ? "Today" : d.formatted("EEEdMMM")).font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accentText).textCase(.uppercase)
                    VerseCard(verse: v, large: false, isFavorite: favoriteRefs.contains(v.reference)) { toggleFavorite(v) }
                }
            }
        }
    }

    private func toggleFavorite(_ v: Verse) {
        Haptics.tap()
        if let existing = favorites.first(where: { $0.reference == v.reference }) {
            context.delete(existing)
        } else {
            context.insert(FavoriteVerse(reference: v.reference))
        }
        context.saveQuietly()
    }
}

struct VerseCard: View {
    let verse: Verse
    var large: Bool
    var isFavorite: Bool
    var onFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 18 : 10) {
            HStack {
                Text(verse.theme.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .default)).tracking(1)
                    .foregroundStyle(Theme.accentText)
                Spacer()
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Theme.deepOrange : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
            }
            Text("“\(verse.text)”")
                .font(.system(large ? .title2 : .body, design: .default))
                .lineSpacing(large ? 6 : 3)
                .foregroundStyle(Theme.text)
            Text(verse.reference)
                .font(.system(large ? .headline : .subheadline, design: .default, weight: .semibold))
                .foregroundStyle(Theme.accentText)
        }
        .padding(large ? 24 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(LinearGradient(colors: [Theme.softAccent, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.yellow.opacity(0.35), lineWidth: 0.8))
        .shadow(color: Theme.orange.opacity(0.08), radius: 12, y: 5)
    }
}

/// Lets a ternary pick between two different `ButtonStyle` types.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
