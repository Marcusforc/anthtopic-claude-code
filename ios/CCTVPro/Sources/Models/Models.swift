import SwiftUI
import SwiftData

enum ObjectStatus: String, CaseIterable, Identifiable {
    case planning = "Планирование"
    case installation = "Монтаж"
    case inProgress = "В работе"
    case done = "Завершён"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .planning: return .gray
        case .installation: return Theme.orange
        case .inProgress: return Theme.accent
        case .done: return Theme.green
        }
    }
}

enum ObjectKind: String, CaseIterable, Identifiable {
    case office = "Офис"
    case house = "Дом"
    case shop = "Магазин"
    case warehouse = "Склад"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .office: return "building.2.fill"
        case .house: return "house.fill"
        case .shop: return "storefront.fill"
        case .warehouse: return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .office: return Theme.accent
        case .house: return Theme.purple
        case .shop: return Theme.green
        case .warehouse: return Theme.orange
        }
    }
}

@Model
final class Project {
    var name: String
    var address: String
    var phone: String
    var comment: String
    var statusRaw: String
    var kindRaw: String
    var date: Date
    var cameraCount: Int
    var cableMeters: Int
    var worksCost: Double
    @Attribute(.externalStorage) var coverData: Data?
    @Relationship(deleteRule: .cascade) var equipment: [EquipmentItem] = []
    @Relationship(deleteRule: .cascade) var notes: [ProjectNote] = []
    @Relationship(deleteRule: .cascade) var photos: [ProjectPhoto] = []

    init(name: String, address: String = "", phone: String = "", comment: String = "",
         status: ObjectStatus = .planning, kind: ObjectKind = .house, date: Date = .now,
         cameraCount: Int = 0, cableMeters: Int = 0, worksCost: Double = 0) {
        self.name = name
        self.address = address
        self.phone = phone
        self.comment = comment
        self.statusRaw = status.rawValue
        self.kindRaw = kind.rawValue
        self.date = date
        self.cameraCount = cameraCount
        self.cableMeters = cableMeters
        self.worksCost = worksCost
    }

    var status: ObjectStatus {
        get { ObjectStatus(rawValue: statusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    var kind: ObjectKind {
        get { ObjectKind(rawValue: kindRaw) ?? .house }
        set { kindRaw = newValue.rawValue }
    }

    var equipmentTotal: Double { equipment.reduce(0) { $0 + $1.total } }
    var equipmentPositions: Int { equipment.count }
    var estimateTotal: Double { equipmentTotal + worksCost }
}

@Model
final class EquipmentItem {
    var name: String
    var price: Double
    var quantity: Int

    init(name: String, price: Double, quantity: Int = 1) {
        self.name = name
        self.price = price
        self.quantity = quantity
    }

    var total: Double { price * Double(quantity) }
}

@Model
final class ProjectNote {
    var text: String
    var date: Date

    init(text: String, date: Date = .now) {
        self.text = text
        self.date = date
    }
}

@Model
final class ProjectPhoto {
    @Attribute(.externalStorage) var data: Data
    var date: Date

    init(data: Data, date: Date = .now) {
        self.data = data
        self.date = date
    }
}

#if DEBUG
enum SeedData {
    static func insertIfEmpty(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
        guard count == 0 else { return }
        let p = Project(name: "Иван Петров", address: "Белгород, ул. Примерная, 15", phone: "+7 (910) 123-45-67",
                        comment: "Частный дом. 2 этажа + двор.", status: .installation, kind: .office,
                        cameraCount: 8, cableMeters: 120, worksCost: 10_000)
        p.equipment = [
            EquipmentItem(name: "Камера Hikvision DS-2CD2143G2", price: 4_590, quantity: 8),
            EquipmentItem(name: "Видеорегистратор Hikvision DS-7608NI-K2/8P", price: 14_900),
            EquipmentItem(name: "Жёсткий диск WD Purple 4TB", price: 11_500),
        ]
        context.insert(p)
        context.insert(Project(name: "ООО «ЭлектроДом»", address: "Белгород, ул. Промышленная, 8",
                               status: .inProgress, kind: .house, cameraCount: 16, cableMeters: 230))
        context.insert(Project(name: "Магазин «Продукты»", address: "Белгород, ул. Победы, 3",
                               status: .done, kind: .shop, cameraCount: 4, cableMeters: 60))
    }
}
#endif
