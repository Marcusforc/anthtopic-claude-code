import SwiftUI
import SwiftData

struct EquipmentListView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    @State private var editing: EquipmentItem?
    @State private var showNew = false

    var body: some View {
        List {
            ForEach(project.equipment) { item in
                Button { editing = item } label: { EquipmentRow(item: item) }
                    .buttonStyle(.plain)
                    .swipeActions { Button("Удалить", role: .destructive) { context.delete(item) } }
            }
        }
        .overlay { if project.equipment.isEmpty { Text("Оборудование не добавлено").foregroundStyle(Theme.secondary) } }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Оборудование")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button { showNew = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showNew) { EquipmentEditView(project: project, item: nil) }
        .sheet(item: $editing) { EquipmentEditView(project: project, item: $0) }
    }
}

struct EquipmentRow: View {
    let item: EquipmentItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline.weight(.semibold))
                Text("\(rubles(item.price))  × \(item.quantity)").font(.caption).foregroundStyle(Theme.secondary)
            }
            Spacer()
            Text(rubles(item.total)).font(.subheadline.weight(.semibold))
        }
    }
}

struct EquipmentEditView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let item: EquipmentItem?
    @State private var name: String
    @State private var price: Double
    @State private var quantity: Int

    init(project: Project, item: EquipmentItem?) {
        self.project = project
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _price = State(initialValue: item?.price ?? 0)
        _quantity = State(initialValue: item?.quantity ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Наименование", text: $name)
                HStack {
                    Text("Цена, ₽")
                    TextField("0", value: $price, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                Stepper("Количество: \(quantity)", value: $quantity, in: 1...9999)
            }
            .navigationTitle(item == nil ? "Новая позиция" : "Позиция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if let item {
                            item.name = name; item.price = price; item.quantity = quantity
                        } else {
                            project.equipment.append(EquipmentItem(name: name, price: price, quantity: quantity))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct EstimateView: View {
    @Bindable var project: Project
    @State private var pdfURL: URL?
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                totals
                VStack(alignment: .leading, spacing: 12) {
                    Text("Оборудование").font(.headline)
                    ForEach(project.equipment) { item in
                        EquipmentRow(item: item)
                        Divider().overlay(Theme.stroke)
                    }
                    if project.equipment.isEmpty { Text("Нет позиций").foregroundStyle(Theme.secondary) }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                HStack(spacing: 12) {
                    Button {
                        pdfURL = EstimatePDF.render(project)
                        showShare = pdfURL != nil
                    } label: {
                        Label("Экспорт в PDF", systemImage: "doc")
                            .frame(maxWidth: .infinity).padding(.vertical, 14).card()
                    }
                    ShareLink(item: summary) {
                        Label("Отправить", systemImage: "paperplane")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Смета")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) { if let pdfURL { ShareSheet(items: [pdfURL]) } }
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Итого").font(.subheadline).foregroundStyle(Theme.secondary)
            Text(rubles(project.estimateTotal)).font(.largeTitle.bold()).foregroundStyle(Theme.accent)
            HStack {
                Text("Стоимость оборудования").foregroundStyle(Theme.secondary)
                Spacer()
                Text(rubles(project.equipmentTotal))
            }
            HStack {
                Text("Работы").foregroundStyle(Theme.secondary)
                Spacer()
                TextField("0", value: $project.worksCost, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 120)
                Text("₽")
            }
        }
        .font(.subheadline)
        .padding(16)
        .card()
    }

    private var summary: String {
        var lines = ["Смета: \(project.name)", project.address, ""]
        lines += project.equipment.map { "• \($0.name) — \($0.quantity) × \(rubles($0.price)) = \(rubles($0.total))" }
        lines += ["", "Оборудование: \(rubles(project.equipmentTotal))",
                  "Работы: \(rubles(project.worksCost))", "Итого: \(rubles(project.estimateTotal))"]
        return lines.joined(separator: "\n")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

private struct EstimatePDFPage: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Смета: \(project.name)").font(.title2.bold())
            Text(project.address).font(.subheadline)
            Divider()
            ForEach(project.equipment) { item in
                HStack(alignment: .top) {
                    Text(item.name)
                    Spacer()
                    Text("\(item.quantity) × \(rubles(item.price)) = \(rubles(item.total))")
                }
                .font(.footnote)
            }
            Divider()
            HStack { Text("Оборудование"); Spacer(); Text(rubles(project.equipmentTotal)) }
            HStack { Text("Работы"); Spacer(); Text(rubles(project.worksCost)) }
            HStack { Text("Итого").bold(); Spacer(); Text(rubles(project.estimateTotal)).bold() }
        }
        .padding(32)
        .frame(width: 595, alignment: .leading)
        .foregroundStyle(.black)
        .background(.white)
    }
}

enum EstimatePDF {
    @MainActor
    static func render(_ project: Project) -> URL? {
        let renderer = ImageRenderer(content: EstimatePDFPage(project: project))
        let safeName = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Смета \(safeName).pdf")
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

struct EstimatesListView: View {
    @Query(sort: \Project.date, order: .reverse) private var projects: [Project]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(projects) { project in
                        NavigationLink(destination: EstimateView(project: project)) {
                            HStack {
                                IconBadge(symbol: "doc.text.fill", color: Theme.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name).font(.headline)
                                    Text("\(project.equipmentPositions) позиций").font(.caption).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                Text(rubles(project.estimateTotal)).font(.subheadline.weight(.semibold))
                            }
                            .padding(14)
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .overlay { if projects.isEmpty { Text("Сначала создайте объект").foregroundStyle(Theme.secondary) } }
            .screenBackground()
            .navigationTitle("Сметы")
        }
    }
}
