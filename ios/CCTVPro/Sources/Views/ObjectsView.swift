import SwiftUI
import SwiftData

private enum Scope: String, CaseIterable, Identifiable {
    case all = "Все объекты"
    case planning = "Планирование"
    case active = "В работе"
    case done = "Завершены"

    var id: String { rawValue }

    func matches(_ status: ObjectStatus) -> Bool {
        switch self {
        case .all: return true
        case .planning: return status == .planning
        case .active: return status == .installation || status == .inProgress
        case .done: return status == .done
        }
    }
}

struct ObjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.date, order: .reverse) private var projects: [Project]
    @State private var search = ""
    @State private var scope: Scope = .all
    @State private var showNew = false

    private var filtered: [Project] {
        projects.filter { p in
            scope.matches(p.status)
                && (search.isEmpty
                    || p.name.localizedCaseInsensitiveContains(search)
                    || p.address.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    searchBar
                    stats
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { project in
                            NavigationLink(value: project) { ProjectRow(project: project) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Удалить", systemImage: "trash", role: .destructive) {
                                        context.delete(project)
                                    }
                                }
                        }
                        if filtered.isEmpty {
                            Text("Объектов нет")
                                .foregroundStyle(Theme.secondary)
                                .padding(.top, 40)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .screenBackground()
            .navigationTitle("Объекты")
            .navigationDestination(for: Project.self) { ObjectDetailView(project: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: {
                        Image(systemName: "plus")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Theme.accent, in: Circle())
                    }
                    .accessibilityLabel("Новый объект")
                }
            }
            .sheet(isPresented: $showNew) { ObjectEditView(existing: nil) }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondary)
                TextField("Поиск объектов", text: $search)
            }
            .padding(12)
            .card()
            Menu {
                Picker("Фильтр", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .frame(width: 48, height: 46)
                    .card()
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatTile(symbol: "folder.fill", color: Theme.accent, value: projects.count,
                     title: "Все объекты", selected: scope == .all) { scope = .all }
            StatTile(symbol: "wrench.and.screwdriver.fill", color: Theme.orange,
                     value: projects.filter { Scope.active.matches($0.status) }.count,
                     title: "В работе", selected: scope == .active) { scope = .active }
            StatTile(symbol: "checkmark.circle.fill", color: Theme.green,
                     value: projects.filter { $0.status == .done }.count,
                     title: "Завершены", selected: scope == .done) { scope = .done }
        }
    }
}

private struct StatTile: View {
    let symbol: String
    let color: Color
    let value: Int
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).foregroundStyle(color)
                    Text("\(value)").font(.title2.bold())
                }
                Text(title).font(.caption).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .card()
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? color.opacity(0.6) : .clear))
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let status: ObjectStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.18), in: Capsule())
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: project.kind.symbol, color: project.kind.color, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(project.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    StatusBadge(status: project.status)
                }
                Text(project.address).font(.subheadline).foregroundStyle(Theme.secondary).lineLimit(1)
                HStack(spacing: 14) {
                    Label("\(project.cameraCount) кам.", systemImage: "video")
                    Label("\(project.cableMeters) м", systemImage: "cable.connector")
                    Label(project.date.formatted(.dateTime.day().month(.twoDigits).year()), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .labelStyle(.titleAndIcon)
            }
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.secondary)
        }
        .padding(14)
        .card()
    }
}
