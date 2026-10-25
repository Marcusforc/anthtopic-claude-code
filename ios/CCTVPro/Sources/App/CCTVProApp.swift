import SwiftUI
import SwiftData

@main
struct CCTVProApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Project.self, EquipmentItem.self, ProjectNote.self, ProjectPhoto.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    init() {
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Theme.card)
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
    }

    var body: some View {
        TabView {
            ObjectsView()
                .tabItem { Label("Объекты", systemImage: "folder.fill") }
            CalculatorsView()
                .tabItem { Label("Калькуляторы", systemImage: "square.grid.3x3.fill") }
            EstimatesListView()
                .tabItem { Label("Сметы", systemImage: "doc.text.fill") }
            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.fill") }
        }
        .tint(Theme.accent)
        #if DEBUG
        .onAppear { SeedData.insertIfEmpty(context) }
        #endif
    }
}
