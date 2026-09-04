import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .ptTabBarBackground()

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.clipboard") }
                .ptTabBarBackground()

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .ptTabBarBackground()

            ActivityView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .ptTabBarBackground()

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.circle") }
            .ptTabBarBackground()
        }
    }
}
