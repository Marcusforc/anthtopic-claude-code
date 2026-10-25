import SwiftUI

struct ProfileView: View {
    @AppStorage("profileName") private var name = ""
    @AppStorage("profileCompany") private var company = ""
    @AppStorage("profilePhone") private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "person.fill", color: Theme.accent, size: 56)
                        Text(name.isEmpty ? "Ваше имя" : name).font(.title3.bold())
                    }
                }
                Section("Данные для смет") {
                    TextField("Имя", text: $name)
                    TextField("Компания", text: $company)
                    TextField("Телефон", text: $phone).keyboardType(.phonePad)
                }
                Section("О приложении") {
                    LabeledContent("Версия", value: "1.0")
                    Text("Расчёты калькуляторов ориентировочные: проверяйте их по документации производителей.")
                        .font(.footnote).foregroundStyle(Theme.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Профиль")
        }
    }
}
