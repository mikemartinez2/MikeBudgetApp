import SwiftUI
import SwiftData
// MARK: - BudgetTrackerApp
@main
struct BudgetTrackerApp: App {
    // This sets up the database to hold all 3 types of data
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecurringBill.self,
            RecurringIncome.self,
            RecurringDebt.self,
            Bill.self,
            Income.self,
            Debt.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @AppStorage("userTheme") private var userTheme: String = "System"
    
    var selectedScheme: ColorScheme? {
        switch userTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }


    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Trigger recurring logic
                    RecurringManager.shared.processRecurringItems(context: sharedModelContainer.mainContext)
                    // Schedule Notifications
                    NotificationManager.shared.scheduleNotifications(context: sharedModelContainer.mainContext)
                }
                .preferredColorScheme(selectedScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}