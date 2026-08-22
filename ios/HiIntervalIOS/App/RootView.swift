import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case train
    case plans
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .train: "Train"
        case .plans: "Plans"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .train: "play.fill"
        case .plans: "square.stack.3d.up.fill"
        case .history: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = AppTab.train
    private let usesUITestAccessibilitySize = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        && ProcessInfo.processInfo.environment["HIINTERVAL_UI_TEST_DYNAMIC_TYPE"] == "accessibility5"

    var body: some View {
        TabView(selection: $selectedTab) {
            TrainHomeView()
            .tag(AppTab.train)
            .tabItem { tabLabel(.train) }

            PlansView()
            .tag(AppTab.plans)
            .tabItem { tabLabel(.plans) }

            HistoryView()
            .tag(AppTab.history)
            .tabItem { tabLabel(.history) }

            SettingsView()
            .tag(AppTab.settings)
            .tabItem { tabLabel(.settings) }
        }
        .modifier(UITestDynamicTypeModifier(enabled: usesUITestAccessibilitySize))
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(HITheme.accent)
        .preferredColorScheme(store.data.preferences.appearance.colorScheme)
        .task {
            await synchronizeReminders()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await synchronizeReminders() }
        }
        .alert(
            "HiInterval",
            isPresented: Binding(
                get: { store.lastErrorMessage != nil },
                set: { presented in
                    if !presented { store.clearError() }
                }
            )
        ) {
            Button("OK") { store.clearError() }
        } message: {
            Text(store.lastErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func tabLabel(_ tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
            .accessibilityIdentifier("tab.\(tab.rawValue)")
    }

    private func synchronizeReminders() async {
        _ = try? await store.reminders.synchronize(settings: store.data.preferences.reminders)
    }

}

private struct UITestDynamicTypeModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.dynamicTypeSize(.accessibility5)
        } else {
            content
        }
    }
}
