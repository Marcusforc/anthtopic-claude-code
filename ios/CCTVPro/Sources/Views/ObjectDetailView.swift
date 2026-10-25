import SwiftUI
import SwiftData
import PhotosUI

struct ObjectDetailView: View {
    @Bindable var project: Project
    @State private var showEdit = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cover
                info
                LazyVGrid(columns: columns, spacing: 12) {
                    tile("Камеры", "\(project.cameraCount) камер", "video.fill", Theme.accent) {
                        CounterView(title: "Камеры", unit: "шт.", value: $project.cameraCount, range: 0...512, step: 1)
                    }
                    tile("Кабель", "\(project.cableMeters) м", "cable.connector", Theme.green) {
                        CounterView(title: "Кабель", unit: "м", value: $project.cableMeters, range: 0...100_000, step: 10)
                    }
                    tile("Оборудование", "\(project.equipmentPositions) позиций", "server.rack", Theme.purple) {
                        EquipmentListView(project: project)
                    }
                    tile("Фото", "\(project.photos.count) фото", "photo.fill", Theme.orange) {
                        PhotosView(project: project)
                    }
                    tile("Заметки", "\(project.notes.count) записи", "note.text", Theme.orange) {
                        NotesView(project: project)
                    }
                    tile("Смета", rubles(project.estimateTotal), "doc.text.fill", Theme.accent) {
                        EstimateView(project: project)
                    }
                }
                Button { showEdit = true } label: {
                    Text("Редактировать объект")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) { ObjectEditView(existing: project) }
    }

    private var cover: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = project.coverData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(project.kind.color.opacity(0.15))
                        .overlay(Image(systemName: project.kind.symbol).font(.system(size: 56)).foregroundStyle(project.kind.color))
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()
            StatusBadge(status: project.status).padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoRow("mappin.and.ellipse", project.address)
            infoRow("phone", project.phone)
            infoRow("calendar", project.date.formatted(.dateTime.day().month(.twoDigits).year()))
            infoRow("doc.plaintext", project.comment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func infoRow(_ symbol: String, _ text: String) -> some View {
        if !text.isEmpty {
            Label { Text(text) } icon: { Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24) }
        }
    }

    private func tile<D: View>(_ title: String, _ subtitle: String, _ symbol: String, _ color: Color,
                               @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .card()
        }
        .buttonStyle(.plain)
    }
}

struct CounterView: View {
    let title: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        Form {
            Stepper(value: $value, in: range, step: step) {
                Text("\(value) \(unit)").font(.title2.bold())
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhotosView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(project.photos) { photo in
                    if let image = UIImage(data: photo.data) {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Image(uiImage: image).resizable().scaledToFill())
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .contextMenu {
                                Button("Удалить", systemImage: "trash", role: .destructive) { context.delete(photo) }
                            }
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Фото")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            PhotosPicker(selection: $picked, matching: .images) { Image(systemName: "plus") }
        }
        .onChange(of: picked) { _, items in
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        project.photos.append(ProjectPhoto(data: data))
                    }
                }
                picked = []
            }
        }
    }
}

struct NotesView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    @State private var text = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Новая заметка", text: $text, axis: .vertical)
                    Button("Добавить") {
                        project.notes.append(ProjectNote(text: text))
                        text = ""
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section {
                ForEach(project.notes.sorted { $0.date > $1.date }) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text)
                        Text(note.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(Theme.secondary)
                    }
                    .swipeActions { Button("Удалить", role: .destructive) { context.delete(note) } }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Заметки")
        .navigationBarTitleDisplayMode(.inline)
    }
}
