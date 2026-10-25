import SwiftUI

private struct CalculatorEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let destination: AnyView
}

struct CalculatorsView: View {
    private let entries: [CalculatorEntry] = [
        .init(id: "hdd", title: "HDD Calculator", subtitle: "Расчёт объёма жёсткого диска для хранения архива",
              symbol: "internaldrive.fill", color: Theme.purple, destination: AnyView(HDDCalculatorView())),
        .init(id: "poe", title: "PoE Calculator", subtitle: "Расчёт PoE бюджета для камер",
              symbol: "bolt.fill", color: Theme.green, destination: AnyView(PoECalculatorView())),
        .init(id: "psu", title: "Блок питания", subtitle: "Расчёт мощности блока питания 12V",
              symbol: "power", color: Theme.orange, destination: AnyView(PowerSupplyCalculatorView())),
        .init(id: "cable", title: "Кабель Calculator", subtitle: "Расчёт падения напряжения на кабеле",
              symbol: "cable.connector", color: Theme.accent, destination: AnyView(CableCalculatorView())),
        .init(id: "wifi", title: "Расчёт Wi-Fi", subtitle: "Расчёт зоны покрытия Wi-Fi камер",
              symbol: "wifi", color: .cyan, destination: AnyView(WiFiCalculatorView())),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { e in
                        NavigationLink(destination: e.destination) {
                            HStack(spacing: 14) {
                                IconBadge(symbol: e.symbol, color: e.color)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(e.title).font(.headline)
                                    Text(e.subtitle).font(.caption).foregroundStyle(Theme.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.secondary)
                            }
                            .padding(14)
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Калькуляторы")
        }
    }
}

// MARK: - Общие элементы форм

struct ResultCard: View {
    let title: String
    let value: String
    let color: Color
    var details: [(String, String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(Theme.secondary)
            Text(value).font(.system(size: 36, weight: .bold)).foregroundStyle(color)
            ForEach(details, id: \.0) { label, text in
                HStack {
                    Text(label).foregroundStyle(Theme.secondary)
                    Spacer()
                    Text(text)
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card()
    }
}

struct NumberRow: View {
    let title: String
    @Binding var value: Double
    var unit = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            if !unit.isEmpty { Text(unit).foregroundStyle(Theme.secondary) }
        }
    }
}

struct CalculatorForm<Content: View, Result: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ViewBuilder let result: Result

    var body: some View {
        Form {
            Section { content }
            Section("Результат") { result.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func fmt(_ v: Double, _ digits: Int = 1) -> String {
    v.formatted(.number.precision(.fractionLength(0...digits)).locale(Locale(identifier: "ru_RU")))
}

// MARK: - Калькуляторы

struct HDDCalculatorView: View {
    @State private var cameras = 8
    @State private var resolution: Resolution = .mp4
    @State private var bitrate = 4096.0
    @State private var days = 30
    @State private var codec: Codec = .h265

    var body: some View {
        let r = HDDCalculator.calculate(cameras: cameras, bitrateKbps: Int(bitrate), days: days, codec: codec)
        CalculatorForm(title: "HDD Calculator") {
            Stepper("Количество камер: \(cameras)", value: $cameras, in: 1...512)
            Picker("Разрешение", selection: $resolution) {
                ForEach(Resolution.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: resolution) { _, new in bitrate = Double(new.suggestedBitrate) }
            NumberRow(title: "Битрейт (H.264) на камеру", value: $bitrate, unit: "Кбит/с")
            Stepper("Дней хранения: \(days)", value: $days, in: 1...365)
            Picker("Кодек сжатия", selection: $codec) {
                ForEach(Codec.allCases) { Text($0.rawValue).tag($0) }
            }
        } result: {
            ResultCard(title: "Рекомендуемый объём", value: "\(fmt(r.recommendedTB, 0)) ТБ", color: Theme.accent,
                       details: [("Полезный объём", "\(fmt(r.usableTiB, 2)) ТиБ"),
                                 ("Нужно с запасом 10%", "\(fmt(r.requiredTB, 2)) ТБ")])
        }
    }
}

struct PoECalculatorView: View {
    @State private var cameras = 8
    @State private var watts = 8.0
    @State private var reserve = 20.0

    var body: some View {
        let r = PoECalculator.calculate(cameras: cameras, wattsPerCamera: watts, reservePercent: reserve)
        CalculatorForm(title: "PoE Calculator") {
            Stepper("Количество камер: \(cameras)", value: $cameras, in: 1...512)
            NumberRow(title: "Мощность камеры", value: $watts, unit: "Вт")
            NumberRow(title: "Запас", value: $reserve, unit: "%")
        } result: {
            ResultCard(title: "Рекомендуемый PoE бюджет", value: "\(fmt(r.recommendedBudget, 0)) Вт", color: Theme.green,
                       details: [("Потребление камер", "\(fmt(r.totalWatts)) Вт"),
                                 ("Портов PoE", "\(r.portsNeeded)")])
        }
    }
}

struct PowerSupplyCalculatorView: View {
    @State private var cameras = 8
    @State private var amps = 0.5
    @State private var reserve = 30.0

    var body: some View {
        let r = PowerSupplyCalculator.calculate(cameras: cameras, ampsPerCamera: amps, reservePercent: reserve)
        CalculatorForm(title: "Блок питания") {
            Stepper("Количество камер: \(cameras)", value: $cameras, in: 1...512)
            NumberRow(title: "Ток камеры (12 В)", value: $amps, unit: "А")
            NumberRow(title: "Запас", value: $reserve, unit: "%")
        } result: {
            ResultCard(title: "Рекомендуемый блок питания", value: "\(fmt(r.recommendedAmps, 0)) А", color: Theme.orange,
                       details: [("Мощность", "\(fmt(r.recommendedWatts, 0)) Вт"),
                                 ("Суммарный ток камер", "\(fmt(r.totalAmps, 2)) А")])
        }
    }
}

struct CableCalculatorView: View {
    @State private var length = 50.0
    @State private var current = 0.5
    @State private var section = 0.75
    @State private var supply = 12.0

    var body: some View {
        let r = CableCalculator.calculate(length: length, current: current,
                                          section: max(section, 0.01), supply: max(supply, 1))
        CalculatorForm(title: "Кабель Calculator") {
            NumberRow(title: "Длина линии", value: $length, unit: "м")
            NumberRow(title: "Ток нагрузки", value: $current, unit: "А")
            NumberRow(title: "Сечение жилы (медь)", value: $section, unit: "мм²")
            NumberRow(title: "Напряжение питания", value: $supply, unit: "В")
        } result: {
            ResultCard(title: "Падение напряжения", value: "\(fmt(r.dropPercent))%",
                       color: r.dropPercent <= CableCalculator.limitPercent ? Theme.green : .red,
                       details: [("Потери", "\(fmt(r.dropVolts, 2)) В"),
                                 ("Сопротивление петли", "\(fmt(r.resistance, 2)) Ом"),
                                 ("Макс. длина при \(fmt(CableCalculator.limitPercent, 0))%",
                                  r.maxLength.isFinite ? "\(fmt(r.maxLength, 0)) м" : "—")])
        }
    }
}

struct WiFiCalculatorView: View {
    @State private var area = 500.0
    @State private var band: WiFiBand = .ghz24
    @State private var environment: WiFiEnvironment = .light

    var body: some View {
        let r = WiFiCalculator.calculate(area: area, band: band, environment: environment)
        CalculatorForm(title: "Расчёт Wi-Fi") {
            NumberRow(title: "Площадь покрытия", value: $area, unit: "м²")
            Picker("Диапазон", selection: $band) {
                ForEach(WiFiBand.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Среда", selection: $environment) {
                ForEach(WiFiEnvironment.allCases) { Text($0.rawValue).tag($0) }
            }
        } result: {
            ResultCard(title: "Точек доступа", value: "\(r.accessPoints)", color: .cyan,
                       details: [("Радиус действия", "≈ \(fmt(r.radius, 0)) м"),
                                 ("Площадь одной точки", "≈ \(fmt(r.coverageArea, 0)) м²")])
        }
    }
}
