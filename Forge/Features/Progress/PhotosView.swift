import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Gallery

struct PhotosView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @Query(sort: \PhotoCollection.createdAt) private var collections: [PhotoCollection]

    enum Layout: String, CaseIterable, Identifiable {
        case grid = "Grid", timeline = "Timeline"
        var id: String { rawValue }
    }
    enum Filter: Hashable {
        case all
        case angle(PhotoAngle)
        case collection(UUID)
    }

    @State private var layout: Layout = .grid
    @State private var filter: Filter = .all
    @State private var showAdd = false
    @State private var showCompare = false
    @State private var showCollections = false
    @State private var selected: ProgressPhoto?

    private var filtered: [ProgressPhoto] {
        switch filter {
        case .all: return photos
        case .angle(let a): return photos.filter { $0.angle == a }
        case .collection(let id): return photos.filter { $0.collectionID == id }
        }
    }

    private var byMonth: [MonthGroup] {
        let groups = Dictionary(grouping: filtered) { $0.date.startOfMonth }
        return groups.keys.sorted(by: >).map { MonthGroup(key: $0, photos: groups[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterBar
                Picker("Layout", selection: $layout) {
                    ForEach(Layout.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.pad)

                if photos.isEmpty {
                    EmptyState(icon: "camera", title: "Start your photo timeline",
                               message: "Front, side and back photos, saved privately on this iPhone and never uploaded.",
                               actionTitle: "Add first photo") { showAdd = true }
                } else if filtered.isEmpty {
                    EmptyState(icon: "photo.on.rectangle", title: "Nothing here", message: "No photos match this filter.")
                } else {
                    switch layout {
                    case .grid: gridLayout
                    case .timeline: timelineLayout
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .screenBackground()
        .navigationTitle("Photos")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if photos.count >= 2 {
                    Button { showCompare = true } label: { Image(systemName: "square.split.2x1") }
                        .accessibilityLabel("Compare photos")
                }
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add photo")
            }
        }
        .sheet(isPresented: $showAdd) { AddPhotoView() }
        .sheet(isPresented: $showCollections) { CollectionsSheet() }
        .sheet(item: $selected) { PhotoDetailView(photo: $0) }
        .fullScreenCover(isPresented: $showCompare) { CompareView() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", selected: filter == .all) { filter = .all }
                ForEach(PhotoAngle.allCases) { a in
                    Chip(title: a.title, icon: a.icon, selected: filter == .angle(a)) { filter = .angle(a) }
                }
                ForEach(collections) { c in
                    Chip(title: c.name, icon: "folder", selected: filter == .collection(c.id)) { filter = .collection(c.id) }
                }
                Button { showCollections = true } label: {
                    Label("Collections", systemImage: "folder.badge.plus")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(Theme.accentText)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .overlay(Capsule().stroke(Theme.accentText.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(.horizontal, Theme.pad)
        }
    }

    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(byMonth) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.key.formatted("MMMMy")).font(Theme.display(20)).foregroundStyle(Theme.text)
                        .padding(.horizontal, Theme.pad)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(group.photos) { p in
                            Button { selected = p } label: {
                                StoredImage(fileName: p.fileName, maxPixel: 500)
                                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                    .overlay(alignment: .bottomLeading) {
                                        Text(p.angle.title)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                            .background(Capsule().fill(.black.opacity(0.45)))
                                            .foregroundStyle(.white)
                                            .padding(6)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(p.angle.title) photo, \(p.date.shortDate)")
                        }
                    }
                    .padding(.horizontal, Theme.pad)
                }
            }
        }
    }

    private var timelineLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(filtered) { p in
                Button { selected = p } label: {
                    HStack(spacing: 14) {
                        StoredImage(fileName: p.fileName, maxPixel: 400)
                            .frame(width: 90, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.date.formatted("EEEdMMMy")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            Text(p.angle.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.accentText)
                            if !p.note.isEmpty {
                                Text(p.note).font(.footnote).foregroundStyle(Theme.textSecondary).lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer()
                    }
                    .card(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.pad)
    }
}

struct MonthGroup: Identifiable {
    var id: Date { key }
    var key: Date
    var photos: [ProgressPhoto]
}

// MARK: - Add photo

struct AddPhotoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PhotoCollection.createdAt) private var collections: [PhotoCollection]

    struct Draft: Identifiable {
        let id = UUID()
        var image: UIImage
        var angle: PhotoAngle
    }

    @State private var drafts: [Draft] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var date = Date()
    @State private var note = ""
    @State private var collectionID: UUID?
    @State private var newCollection = ""
    @State private var errorMessage: String?
    @State private var saving = false
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                    }
                    if CameraPicker.isAvailable {
                        Button { showCamera = true } label: { Label("Take photo", systemImage: "camera") }
                    }
                    if loading { ProgressView() }
                } footer: {
                    Text("Photos are copied into Forge's private storage on this device. Nothing is uploaded.")
                }.listRowBackground(Theme.card)

                if !drafts.isEmpty {
                    Section("Photos") {
                        ForEach($drafts) { $d in
                            HStack(spacing: 14) {
                                Image(uiImage: d.image).resizable().scaledToFill()
                                    .frame(width: 64, height: 86)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Picker("Angle", selection: $d.angle) {
                                    ForEach(PhotoAngle.allCases) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .onDelete { drafts.remove(atOffsets: $0) }
                    }.listRowBackground(Theme.card)

                    Section("Details") {
                        DatePicker("Date", selection: $date, in: ...Date())
                        TextField("Note (e.g. morning, fasted, 80 kg)", text: $note, axis: .vertical)
                        Picker("Collection", selection: $collectionID) {
                            Text("None").tag(UUID?.none)
                            ForEach(collections) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                        HStack {
                            TextField("New collection", text: $newCollection)
                            Button("Create") { createCollection() }.disabled(newCollection.trimmed.isEmpty)
                        }
                    }.listRowBackground(Theme.card)
                }
            }
            .warmForm()
            .navigationTitle("Add photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(drafts.isEmpty || saving)
                }
            }
            .onChange(of: pickerItems) { _, items in Task { await load(items) } }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { img in
                    let used = Set(drafts.map(\.angle))
                    let angle = PhotoAngle.allCases.first { !used.contains($0) } ?? .front
                    drafts.append(Draft(image: img, angle: angle))
                }
                .ignoresSafeArea()
            }
            .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil },
                                                         set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        loading = true
        defer { loading = false }
        var failed = 0
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                let used = Set(drafts.map(\.angle))
                let angle = PhotoAngle.allCases.first { !used.contains($0) } ?? .front
                drafts.append(Draft(image: img, angle: angle))
            } else {
                failed += 1
            }
        }
        pickerItems = []
        if failed > 0 { errorMessage = "\(failed) photo(s) could not be loaded." }
    }

    private func createCollection() {
        let c = PhotoCollection(name: newCollection.trimmed)
        context.insert(c)
        context.saveQuietly()
        collectionID = c.id
        newCollection = ""
    }

    private func save() {
        saving = true
        var savedFiles: [String] = []
        do {
            for d in drafts {
                let file = try PhotoStore.save(d.image)
                savedFiles.append(file)
                context.insert(ProgressPhoto(date: date, angle: d.angle, note: note.trimmed,
                                             fileName: file, collectionID: collectionID))
            }
            try context.save()
            Haptics.success()
            dismiss()
        } catch {
            // Roll back files written so far so nothing is orphaned.
            savedFiles.forEach { PhotoStore.delete(fileName: $0) }
            errorMessage = error.localizedDescription
            saving = false
        }
    }
}

// MARK: - Detail

struct PhotoDetailView: View {
    @Bindable var photo: ProgressPhoto
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PhotoCollection.createdAt) private var collections: [PhotoCollection]
    @State private var exportURL: URL?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StoredImage(fileName: photo.fileName, maxPixel: 1400, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(spacing: 0) {
                        Picker("Angle", selection: Binding(get: { photo.angle }, set: { photo.angle = $0 })) {
                            ForEach(PhotoAngle.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 12)
                        DatePicker("Date", selection: $photo.date, in: ...Date())
                        Divider().padding(.vertical, 8)
                        Picker("Collection", selection: $photo.collectionID) {
                            Text("None").tag(UUID?.none)
                            ForEach(collections) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                    }
                    .card()

                    TextField("Add a note", text: $photo.note, axis: .vertical)
                        .lineLimit(2...6)
                        .card()

                    HStack(spacing: 12) {
                        if let exportURL {
                            ShareLink(item: exportURL) { Label("Export", systemImage: "square.and.arrow.up") }
                                .buttonStyle(SoftButtonStyle())
                        }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                            .buttonStyle(SoftButtonStyle())
                    }
                }
                .padding(Theme.pad)
            }
            .screenBackground()
            .keyboardDoneToolbar()
            .navigationTitle(photo.date.formatted("dMMMy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { context.saveQuietly(); dismiss() }.fontWeight(.semibold) } }
            .task { exportURL = PhotoStore.exportURL(for: photo) }
            .confirmationDialog("Delete this photo permanently?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete photo", role: .destructive) {
                    context.deletePhoto(photo)
                    dismiss()
                }
            } message: { Text("This removes the file from your iPhone. It can't be undone.") }
        }
    }
}

// MARK: - Collections

struct CollectionsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PhotoCollection.createdAt) private var collections: [PhotoCollection]
    @Query private var photos: [ProgressPhoto]
    @State private var name = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New collection (e.g. 12-week cut)", text: $name)
                        Button("Add") {
                            context.insert(PhotoCollection(name: name.trimmed))
                            context.saveQuietly()
                            name = ""
                        }.disabled(name.trimmed.isEmpty)
                    }
                }.listRowBackground(Theme.card)
                Section {
                    ForEach(collections) { c in
                        HStack {
                            Text(c.name)
                            Spacer()
                            Text("\(photos.filter { $0.collectionID == c.id }.count)").foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            let c = collections[i]
                            photos.filter { $0.collectionID == c.id }.forEach { $0.collectionID = nil }
                            context.delete(c)
                        }
                        context.saveQuietly()
                    }
                } footer: { Text("Deleting a collection keeps its photos.") }
                .listRowBackground(Theme.card)
            }
            .warmForm()
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Compare

struct CompareView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProgressPhoto.date) private var photos: [ProgressPhoto]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]

    @State private var before: ProgressPhoto?
    @State private var after: ProgressPhoto?
    @State private var split: CGFloat = 0.5
    @State private var sideBySide = false
    @State private var picking: Slot?

    enum Slot: String, Identifiable {
        case before, after
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Mode", selection: $sideBySide) {
                        Text("Slider").tag(false)
                        Text("Side by side").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if let before, let after {
                        if sideBySide {
                            HStack(spacing: 8) {
                                photoTile(before, label: "Before")
                                photoTile(after, label: "After")
                            }
                        } else {
                            slider(before: before, after: after)
                        }
                        summary(before: before, after: after)
                    } else {
                        EmptyState(icon: "square.split.2x1", title: "Pick two photos",
                                   message: "Choose a before and an after to compare.")
                    }

                    HStack(spacing: 12) {
                        Button { picking = .before } label: { Label("Before", systemImage: "arrow.left.circle") }
                            .buttonStyle(SoftButtonStyle(compact: true))
                        Button { picking = .after } label: { Label("After", systemImage: "arrow.right.circle") }
                            .buttonStyle(SoftButtonStyle(compact: true))
                    }
                }
                .padding(Theme.pad)
            }
            .screenBackground()
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            .sheet(item: $picking) { slot in
                PhotoPickerGrid(photos: photos) { p in
                    if slot == .before { before = p } else { after = p }
                }
            }
            .onAppear { preselect() }
        }
    }

    private func preselect() {
        guard before == nil, after == nil, photos.count >= 2 else { return }
        // Same angle as the newest photo: oldest vs newest.
        if let newest = photos.last {
            let same = photos.filter { $0.angle == newest.angle }
            if same.count >= 2 {
                before = same.first
                after = same.last
                return
            }
        }
        before = photos.first
        after = photos.last
    }

    private func slider(before: ProgressPhoto, after: ProgressPhoto) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .leading) {
                StoredImage(fileName: after.fileName, maxPixel: 1400)
                    .frame(width: w, height: h)
                StoredImage(fileName: before.fileName, maxPixel: 1400)
                    .frame(width: w, height: h)
                    .mask(alignment: .leading) { Rectangle().frame(width: w * split) }
                // Divider + handle
                Rectangle().fill(.white).frame(width: 2, height: h)
                    .offset(x: w * split - 1)
                    .shadow(radius: 3)
                Circle().fill(.white).frame(width: 40, height: 40)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.deepOrange))
                    .shadow(color: .black.opacity(0.25), radius: 6)
                    .offset(x: w * split - 20, y: 0)
                labelPill("Before").position(x: 44, y: 22)
                labelPill("After").position(x: w - 38, y: 22)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                split = min(max(v.location.x / w, 0.02), 0.98)
            })
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityLabel("Before and after slider")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: split = min(split + 0.1, 0.98)
            case .decrement: split = max(split - 0.1, 0.02)
            @unknown default: break
            }
        }
    }

    private func labelPill(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.5)))
    }

    private func photoTile(_ p: ProgressPhoto, label: String) -> some View {
        VStack(spacing: 6) {
            StoredImage(fileName: p.fileName, maxPixel: 900)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("\(label) · \(p.date.shortDate)").font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    private func nearestWeight(to date: Date) -> Double? {
        weights.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?.kg
    }

    private func summary(before: ProgressPhoto, after: ProgressPhoto) -> some View {
        let days = abs(daysBetween(before.date, after.date))
        let wb = nearestWeight(to: before.date)
        let wa = nearestWeight(to: after.date)
        return HStack(spacing: 10) {
            StatTile(value: "\(days)", label: "Days apart", icon: "calendar")
            if let wb, let wa {
                let d = wa - wb
                StatTile(value: "\(d >= 0 ? "+" : "−")\(abs(d).oneDecimal) kg", label: "Weight change", icon: "scalemass")
            }
        }
    }
}

struct PhotoPickerGrid: View {
    let photos: [ProgressPhoto]
    var onPick: (ProgressPhoto) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(photos.reversed()) { p in
                        Button {
                            onPick(p)
                            dismiss()
                        } label: {
                            StoredImage(fileName: p.fileName, maxPixel: 400)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .overlay(alignment: .bottom) {
                                    Text("\(p.angle.title) · \(p.date.shortDate)")
                                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 3)
                                        .background(.black.opacity(0.45))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.pad)
            }
            .screenBackground()
            .navigationTitle("Choose a photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}
