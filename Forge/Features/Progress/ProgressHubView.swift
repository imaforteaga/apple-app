import SwiftUI
import SwiftData
import Charts

struct ProgressHubView: View {
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @Query private var profiles: [UserProfile]
    @Query private var milestones: [Milestone]

    private var activeMilestones: [Milestone] { milestones.filter { !$0.isCompleted } }

    var body: some View {
        WithScore { engine in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    bodySnapshot
                    NavigationLink { PhotosView() } label: { photosCard }.buttonStyle(.plain)
                    NavigationLink { ScoreView() } label: { scoreRow(engine) }.buttonStyle(.plain)
                    NavigationLink { MilestonesView() } label: {
                        hubRow("flag", "Milestones",
                               activeMilestones.isEmpty ? "Set measurable goals" : "\(activeMilestones.count) active · \(milestones.count - activeMilestones.count) completed")
                    }.buttonStyle(.plain)
                    NavigationLink { CalendarView() } label: {
                        hubRow("calendar", "Calendar & reports", "Review any day, weekly and monthly reports")
                    }.buttonStyle(.plain)
                    NavigationLink { JournalView() } label: {
                        hubRow("square.and.pencil", "Journal", "Private daily reflection")
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.pad)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .navigationTitle("Progress")
        }
    }

    private var bodySnapshot: some View {
        let current = weights.first?.kg ?? profiles.first?.startWeightKg
        let first = weights.last?.kg
        let series = Array(weights.reversed().suffix(30))
        return NavigationLink {
            BodyView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Body").font(Theme.display(22)).foregroundStyle(Theme.text)
                    Spacer()
                    Text("Weight & measurements").font(.caption).foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let current {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(current.clean).font(Theme.number(44)).foregroundStyle(Theme.text)
                                Text("kg").foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            Text("No weight yet").foregroundStyle(Theme.textSecondary)
                        }
                        if let current, let first, series.count > 1 {
                            let d = current - first
                            Text("\(d >= 0 ? "+" : "−")\(abs(d).oneDecimal) kg since first entry")
                                .font(.footnote).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    if series.count > 1 {
                        Chart(series) { w in
                            LineMark(x: .value("Date", w.date), y: .value("kg", w.kg))
                                .interpolationMethod(.catmullRom).foregroundStyle(Theme.orange)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }
                        .chartXAxis(.hidden).chartYAxis(.hidden)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(width: 120, height: 50)
                    }
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos").font(Theme.display(22)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(photos.count) saved").font(.caption).foregroundStyle(Theme.textSecondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            if photos.isEmpty {
                Text("Add front, side and back photos to see your transformation over time.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(photos.prefix(4)) { p in
                        StoredImage(fileName: p.fileName, maxPixel: 300)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .card()
    }

    private func scoreRow(_ engine: ScoreEngine) -> some View {
        let w = engine.week
        return HStack(spacing: 14) {
            ProgressRing(progress: w.overall / 100, lineWidth: 7) {
                Text("\(Int(w.overall.rounded()))").font(Theme.number(17)).foregroundStyle(Theme.text)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Transformation Score").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text(engine.label(for: w.overall)).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }

    private func hubRow(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemName: icon, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text(sub).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }
}

// MARK: - Body (weight + measurements)

struct BodyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query private var profiles: [UserProfile]

    enum TimeRange: String, CaseIterable, Identifiable {
        case m1 = "1M", m3 = "3M", m6 = "6M", all = "All"
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .m1: return 30
            case .m3: return 90
            case .m6: return 180
            case .all: return nil
            }
        }
    }

    @State private var range: TimeRange = .m3
    @State private var site: MeasurementSite = .waist
    @State private var showWeight = false
    @State private var showMeasure = false

    private var filteredWeights: [WeightEntry] {
        let asc = weights.reversed() as [WeightEntry]
        guard let d = range.days else { return asc }
        let from = Date().addingDays(-d)
        return asc.filter { $0.date >= from }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weightCard
                measurementsCard
                historySection
            }
            .padding(.horizontal, Theme.pad)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Body")
        .sheet(isPresented: $showWeight) { AddWeightView() }
        .sheet(isPresented: $showMeasure) { AddMeasurementView() }
    }

    private var weightCard: some View {
        let pts = filteredWeights
        let current = weights.first?.kg
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Weight", subtitle: profiles.first.map { "Height \($0.heightCm.clean) cm" }) {
                Button { showWeight = true } label: { Label("Add", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
            Picker("Range", selection: $range) {
                ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if pts.count < 2 {
                Text(weights.isEmpty ? "Add your weight to start the chart." : "Add another weigh-in to see the trend.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary).padding(.vertical, 30)
            } else {
                Chart(pts) { w in
                    AreaMark(x: .value("Date", w.date), y: .value("kg", w.kg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [Theme.orange.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", w.date), y: .value("kg", w.kg))
                        .interpolationMethod(.catmullRom).foregroundStyle(Theme.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    PointMark(x: .value("Date", w.date), y: .value("kg", w.kg)).foregroundStyle(Theme.deepOrange)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 190)
            }
            if let current {
                HStack(spacing: 10) {
                    StatTile(value: "\(current.clean) kg", label: "Current")
                    if let first = pts.first, pts.count > 1 {
                        let d = current - first.kg
                        StatTile(value: "\(d >= 0 ? "+" : "−")\(abs(d).oneDecimal)", label: "In range")
                    }
                    if let lo = pts.map(\.kg).min(), let hi = pts.map(\.kg).max(), pts.count > 1 {
                        StatTile(value: "\(lo.clean)–\(hi.clean)", label: "Low–high")
                    }
                }
            }
        }
        .card()
    }

    private var measurementsCard: some View {
        let series: [DatedValue] = measurements.reversed().compactMap { m in
            site.value(in: m).map { DatedValue(date: m.date, value: $0) }
        }
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Measurements", subtitle: "Tape measure, in cm") {
                Button { showMeasure = true } label: { Label("Add", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MeasurementSite.allCases) { s in
                        Chip(title: s.title, selected: s == site) { site = s }
                    }
                }
            }
            if series.count < 2 {
                Text(series.isEmpty ? "No \(site.title.lowercased()) entries yet." : "Add another entry to see change over time.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary).padding(.vertical, 24)
            } else {
                Chart(series) { p in
                    LineMark(x: .value("Date", p.date), y: .value(site.title, p.value))
                        .foregroundStyle(Theme.orange).interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    PointMark(x: .value("Date", p.date), y: .value(site.title, p.value)).foregroundStyle(Theme.deepOrange)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
                if let f = series.first, let l = series.last {
                    let d = l.value - f.value
                    Text("\(site.title): \(l.value.clean) \(site.unit) · \(d >= 0 ? "+" : "−")\(abs(d).oneDecimal) \(site.unit) since \(f.date.shortDate)")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accentText)
                }
            }
        }
        .card()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("History")
            if weights.isEmpty && measurements.isEmpty {
                Text("Nothing logged yet.").font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            ForEach(weights.prefix(8)) { w in
                HStack {
                    Image(systemName: "scalemass").foregroundStyle(Theme.accentText)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(w.kg.clean) kg").font(.subheadline.weight(.semibold))
                        Text(w.date.formatted("EEEdMMMy") + (w.note.isEmpty ? "" : " · \(w.note)"))
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button(role: .destructive) { context.delete(w); context.saveQuietly() } label: {
                        Image(systemName: "trash").foregroundStyle(Theme.textSecondary)
                    }
                }
                .card(padding: 12)
            }
            ForEach(measurements.prefix(6)) { m in
                HStack {
                    Image(systemName: "ruler").foregroundStyle(Theme.accentText)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.date.formatted("EEEdMMMy")).font(.subheadline.weight(.semibold))
                        Text(MeasurementSite.allCases.compactMap { s in
                            s.value(in: m).map { "\(s.title) \($0.clean)" }
                        }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button(role: .destructive) { context.delete(m); context.saveQuietly() } label: {
                        Image(systemName: "trash").foregroundStyle(Theme.textSecondary)
                    }
                }
                .card(padding: 12)
            }
        }
    }
}

// MARK: - Forms

struct AddWeightView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var kg: Double?
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberField("Weight", value: $kg, unit: "kg", placeholder: weights.first.map { $0.kg.clean } ?? "0")
                    DatePicker("Date", selection: $date, in: ...Date())
                    TextField("Note (optional)", text: $note)
                } footer: { Text("Weigh yourself at the same time of day for a more useful trend.") }
                .listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle("Add weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .disabled(!((kg ?? 0) >= 20 && (kg ?? 0) <= 400))
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let kg else { return }
        context.insert(WeightEntry(date: date, kg: kg, note: note.trimmed))
        context.saveQuietly()
        _ = MilestoneSync.sync(context)
        Haptics.success()
        dismiss()
    }
}

struct AddMeasurementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var previous: [BodyMeasurement]
    @State private var date = Date()
    @State private var values: [MeasurementSite: Double?] = [:]
    @State private var note = ""

    private func binding(_ s: MeasurementSite) -> Binding<Double?> {
        Binding(get: { values[s] ?? nil }, set: { values[s] = .some($0) })
    }
    private var hasAny: Bool { values.values.contains { $0 != nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section { DatePicker("Date", selection: $date, in: ...Date()) }.listRowBackground(Theme.card)
                Section {
                    ForEach(MeasurementSite.allCases) { s in
                        NumberField(s.title + (s == .bodyFat ? " (optional)" : ""), value: binding(s), unit: s.unit,
                                    placeholder: previous.first.flatMap { s.value(in: $0)?.clean } ?? "–")
                    }
                } header: { Text("Fill in what you measured") } footer: {
                    Text("Faded numbers show your last entry.")
                }.listRowBackground(Theme.card)
                Section { TextField("Note", text: $note) }.listRowBackground(Theme.card)
            }
            .warmForm()
            .keyboardDoneToolbar()
            .navigationTitle("Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!hasAny)
                }
            }
        }
    }

    private func save() {
        let m = BodyMeasurement(date: date)
        m.chest = values[.chest] ?? nil
        m.waist = values[.waist] ?? nil
        m.arms = values[.arms] ?? nil
        m.forearms = values[.forearms] ?? nil
        m.thighs = values[.thighs] ?? nil
        m.calves = values[.calves] ?? nil
        m.neck = values[.neck] ?? nil
        m.bodyFat = values[.bodyFat] ?? nil
        m.note = note.trimmed
        context.insert(m)
        context.saveQuietly()
        Haptics.success()
        dismiss()
    }
}
