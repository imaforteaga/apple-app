import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    enum Mode: String, CaseIterable, Identifiable {
        case list = "Entries", calendar = "Calendar"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .list
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var editing: JournalEntry?
    @State private var month = Date()
    @State private var selectedDay = Date()

    private var filtered: [JournalEntry] {
        entries.filter { e in
            (!favoritesOnly || e.isFavorite) &&
            (search.trimmed.isEmpty || e.searchableText.contains(search.trimmed.lowercased()))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button { newEntry(on: Date()) } label: {
                    Label("Write today's entry", systemImage: "square.and.pencil")
                }
                .buttonStyle(PrimaryButtonStyle())

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)

                if mode == .calendar { calendarMode } else { listMode }
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Journal")
        .searchable(text: $search, prompt: "Search entries")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { favoritesOnly.toggle() } label: {
                    Image(systemName: favoritesOnly ? "star.fill" : "star")
                }
                .accessibilityLabel("Show favorites only")
            }
        }
        .sheet(item: $editing) { JournalEditor(entry: $0) }
    }

    private func newEntry(on day: Date) {
        let e = JournalEntry(date: day.isToday ? Date() : (Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: day) ?? day))
        context.insert(e)
        editing = e
    }

    // MARK: List

    private var listMode: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entries.isEmpty {
                EmptyState(icon: "book", title: "Your private journal",
                           message: "Reflect on your discipline, wins and what to improve. Entries stay on this device.")
            } else if filtered.isEmpty {
                Text("No entries match.").foregroundStyle(Theme.textSecondary)
            }
            ForEach(filtered) { e in entryCard(e) }
        }
    }

    private func entryCard(_ e: JournalEntry) -> some View {
        Button { editing = e } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: e.mood.icon).foregroundStyle(Theme.orange)
                    Text(e.date.formatted("EEEdMMMy")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                    Spacer()
                    if e.isFavorite { Image(systemName: "star.fill").foregroundStyle(Theme.yellow) }
                }
                Text(e.preview).font(.system(.subheadline, design: .default)).foregroundStyle(Theme.textSecondary)
                    .lineLimit(3).multilineTextAlignment(.leading)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: Calendar

    private var calendarMode: some View {
        let dayEntries = entries.filter { $0.date.isSameDay(as: selectedDay) }
        return VStack(alignment: .leading, spacing: 14) {
            MonthGrid(month: $month, selected: $selectedDay) { d in
                entries.filter { $0.date.isSameDay(as: d) }.count
            }
            .card()
            SectionTitle(selectedDay.isToday ? "Today" : selectedDay.formatted("EEEdMMMM"))
            if dayEntries.isEmpty {
                Text("No entries this day.").font(.footnote).foregroundStyle(Theme.textSecondary)
                Button("Add entry for this day") { newEntry(on: selectedDay) }.buttonStyle(SoftButtonStyle(compact: true))
            }
            ForEach(dayEntries) { entryCard($0) }
        }
    }
}

// MARK: - Editor

struct JournalEditor: View {
    @Bindable var entry: JournalEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("journalPrompts") private var showPrompts = true
    @State private var confirmDelete = false
    @State private var deleted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DatePicker("Date", selection: $entry.date, in: ...Date())
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("How are you feeling?").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 8) {
                            ForEach(Mood.allCases) { m in
                                Button { entry.mood = m; Haptics.select() } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: m.icon).font(.title3)
                                        Text(m.title).font(.system(size: 10, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .foregroundStyle(entry.mood == m ? Color.white : Theme.text)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(entry.mood == m ? AnyShapeStyle(Theme.buttonGradient) : AnyShapeStyle(Theme.card)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    field("My day", "Write freely about your day, thoughts and discipline…", $entry.text, lines: 5...12)
                    field("Achievements", "What went well today?", $entry.achievements)
                    field("To improve", "What do I want to do better?", $entry.improvements)
                    field("Reflection", "Personal reflection", $entry.reflection)

                    Toggle("Guided prompts", isOn: $showPrompts).tint(Theme.orange)
                    if showPrompts {
                        ForEach(JournalPrompt.allCases) { p in
                            field(p.rawValue, "Optional", Binding(
                                get: { entry.prompts[p.rawValue] ?? "" },
                                set: { v in var d = entry.prompts; d[p.rawValue] = v; entry.prompts = d }))
                        }
                    }

                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete entry", systemImage: "trash") }
                        .font(.footnote)
                }
                .padding(Theme.pad)
            }
            .screenBackground()
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .navigationTitle("Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { entry.isFavorite.toggle() } label: {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(entry.isFavorite ? Theme.yellow : Theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleted = true
                    context.delete(entry)
                    context.saveQuietly()
                    dismiss()
                }
            }
            .onDisappear {
                guard !deleted else { return }
                if entry.isEmpty {
                    context.delete(entry)
                } else {
                    entry.updatedAt = Date()
                }
                context.saveQuietly()
            }
        }
        .interactiveDismissDisabled(false)
    }

    private func field(_ title: String, _ placeholder: String, _ text: Binding<String>, lines: ClosedRange<Int> = 2...6) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(lines)
                .font(.system(.body, design: .default))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        }
    }
}
