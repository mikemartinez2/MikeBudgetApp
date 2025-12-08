import SwiftUI

struct ContentView: View {
    @StateObject private var navState = NavigationState()
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Overview", systemImage: "chart.pie.fill")
                }
            
            IncomeView()
                .tabItem {
                    Label("Income", systemImage: "dollarsign.circle.fill")
                }
            
            BillsView()
                .tabItem {
                    Label("Bills", systemImage: "list.bullet.rectangle.portrait.fill")
                }
            
            DebtView()
                .tabItem {
                    Label("Debts", systemImage: "creditcard.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(navState)
    }
}
