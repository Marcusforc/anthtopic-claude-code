import SwiftUI
import SwiftData
import PhotosUI

struct ObjectEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let existing: Project?

    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var comment: String
    @State private var kind: ObjectKind
    @State private var status: ObjectStatus
    @State private var date: Date
    @State private var cameras: Int
    @State private var cable: Int
    @State private var coverData: Data?
    @State private var pickerItem: PhotosPickerItem?

    init(existing: Project?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _address = State(initialValue: existing?.address ?? "")
        _phone = State(initialValue: existing?.phone ?? "")
        _comment = State(initialValue: existing?.comment ?? "")
        _kind = State(initialValue: existing?.kind ?? .house)
        _status = State(initialValue: existing?.status ?? .planning)
        _date = State(initialValue: existing?.date ?? .now)
        _cameras = State(initialValue: existing?.cameraCount ?? 0)
        _cable = State(initialValue: existing?.cableMeters ?? 0)
        _coverData = State(initialValue: existing?.coverData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Объект") {
                    TextField("Название / клиент", text: $name)
                    TextField("Адрес", text: $address)
                    TextField("Телефон", text: $phone).keyboardType(.phonePad)
                    TextField("Описание", text: $comment, axis: .vertical)
                }
                Section {
                    Picker("Тип", selection: $kind) {
                        ForEach(ObjectKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Статус", selection: $status) {
                        ForEach(ObjectStatus.allCases) { Text($0.rawValue).tag($0) }
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }
                Section {
                    Stepper("Камер: \(cameras)", value: $cameras, in: 0...512)
                    Stepper("Кабеля: \(cable) м", value: $cable, in: 0...100_000, step: 10)
                }
                Section("Обложка") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(coverData == nil ? "Выбрать фото" : "Заменить фото", systemImage: "photo")
                    }
                    if coverData != nil {
                        Button("Убрать фото", role: .destructive) { coverData = nil }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(existing == nil ? "Новый объект" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { coverData = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }

    private func save() {
        let project = existing ?? Project(name: name)
        project.name = name.trimmingCharacters(in: .whitespaces)
        project.address = address
        project.phone = phone
        project.comment = comment
        project.kind = kind
        project.status = status
        project.date = date
        project.cameraCount = cameras
        project.cableMeters = cable
        project.coverData = coverData
        if existing == nil { context.insert(project) }
        dismiss()
    }
}
