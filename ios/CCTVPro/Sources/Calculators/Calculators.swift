import Foundation

/// Чистая логика калькуляторов без UI: все формулы ориентировочные.

enum Codec: String, CaseIterable, Identifiable {
    case h264 = "H.264"
    case h265 = "H.265"
    case h265plus = "H.265+"

    var id: String { rawValue }

    /// Во сколько раз поток меньше, чем у H.264 при том же качестве.
    var factor: Double {
        switch self {
        case .h264: return 1.0
        case .h265: return 0.6
        case .h265plus: return 0.4
        }
    }
}

enum Resolution: String, CaseIterable, Identifiable {
    case mp2 = "2 MP (1920 × 1080)"
    case mp4 = "4 MP (2560 × 1440)"
    case mp5 = "5 MP (2592 × 1944)"
    case mp8 = "8 MP (3840 × 2160)"

    var id: String { rawValue }

    /// Типичный битрейт H.264, Кбит/с.
    var suggestedBitrate: Int {
        switch self {
        case .mp2: return 2048
        case .mp4: return 4096
        case .mp5: return 6144
        case .mp8: return 8192
        }
    }
}

struct HDDResult: Equatable {
    let rawTB: Double
    let requiredTB: Double
    let recommendedTB: Double
    /// Объём, который покажет ОС (диск считается в ТБ, ОС — в ТиБ).
    let usableTiB: Double
}

enum HDDCalculator {
    static let reserve = 0.10

    static func calculate(cameras: Int, bitrateKbps: Int, days: Int, codec: Codec) -> HDDResult {
        let bytesPerSecond = Double(bitrateKbps) * 1000 / 8
        let raw = bytesPerSecond * 86_400 * Double(cameras) * Double(days) * codec.factor / 1e12
        let required = raw * (1 + reserve)
        let recommended = max(1, required.rounded(.up))
        return HDDResult(rawTB: raw, requiredTB: required, recommendedTB: recommended,
                         usableTiB: recommended * 1e12 / pow(2, 40))
    }
}

private func roundUp(_ value: Double, to steps: [Double], fallbackStep: Double) -> Double {
    steps.first { $0 >= value } ?? (value / fallbackStep).rounded(.up) * fallbackStep
}

struct PoEResult: Equatable {
    let totalWatts: Double
    let recommendedBudget: Double
    let portsNeeded: Int
}

enum PoECalculator {
    static let budgets: [Double] = [30, 60, 120, 150, 250, 300, 370, 400, 500]

    static func calculate(cameras: Int, wattsPerCamera: Double, reservePercent: Double) -> PoEResult {
        let total = Double(cameras) * wattsPerCamera
        let required = total * (1 + reservePercent / 100)
        return PoEResult(totalWatts: total,
                         recommendedBudget: roundUp(required, to: budgets, fallbackStep: 100),
                         portsNeeded: cameras)
    }
}

struct PowerSupplyResult: Equatable {
    let totalAmps: Double
    let recommendedAmps: Double
    let recommendedWatts: Double
}

enum PowerSupplyCalculator {
    static let voltage = 12.0
    static let sizes: [Double] = [1, 2, 3, 5, 10, 15, 20, 30, 40, 60]

    static func calculate(cameras: Int, ampsPerCamera: Double, reservePercent: Double) -> PowerSupplyResult {
        let total = Double(cameras) * ampsPerCamera
        let required = total * (1 + reservePercent / 100)
        let amps = roundUp(required, to: sizes, fallbackStep: 10)
        return PowerSupplyResult(totalAmps: total, recommendedAmps: amps, recommendedWatts: amps * voltage)
    }
}

struct CableResult: Equatable {
    let resistance: Double
    let dropVolts: Double
    let dropPercent: Double
    /// Максимальная длина при падении не более `limitPercent`.
    let maxLength: Double
}

enum CableCalculator {
    /// Удельное сопротивление меди, Ом·мм²/м.
    static let copperResistivity = 0.0175
    static let limitPercent = 5.0

    static func calculate(length: Double, current: Double, section: Double, supply: Double) -> CableResult {
        let loopResistance = copperResistivity * 2 * length / section
        let drop = current * loopResistance
        let perMeter = current * copperResistivity * 2 / section
        let maxLength = perMeter > 0 ? supply * limitPercent / 100 / perMeter : .infinity
        return CableResult(resistance: loopResistance, dropVolts: drop,
                           dropPercent: drop / supply * 100, maxLength: maxLength)
    }
}

enum WiFiBand: String, CaseIterable, Identifiable {
    case ghz24 = "2.4 ГГц"
    case ghz5 = "5 ГГц"
    var id: String { rawValue }
}

enum WiFiEnvironment: String, CaseIterable, Identifiable {
    case open = "Открытое пространство"
    case light = "Лёгкие преграды"
    case dense = "Капитальные стены"
    var id: String { rawValue }
}

struct WiFiResult: Equatable {
    let radius: Double
    let coverageArea: Double
    let accessPoints: Int
}

enum WiFiCalculator {
    static func radius(band: WiFiBand, environment: WiFiEnvironment) -> Double {
        switch (environment, band) {
        case (.open, .ghz24): return 100
        case (.open, .ghz5): return 50
        case (.light, .ghz24): return 40
        case (.light, .ghz5): return 20
        case (.dense, .ghz24): return 20
        case (.dense, .ghz5): return 10
        }
    }

    /// Круги покрытия перекрываются, поэтому полезная площадь — 70% от πr².
    static func calculate(area: Double, band: WiFiBand, environment: WiFiEnvironment) -> WiFiResult {
        let r = radius(band: band, environment: environment)
        let coverage = Double.pi * r * r
        let usable = coverage * 0.7
        return WiFiResult(radius: r, coverageArea: coverage, accessPoints: max(1, Int((area / usable).rounded(.up))))
    }
}
