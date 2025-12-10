import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @AppStorage("userTheme") private var userTheme: String = "System"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("notificationTime") private var notificationTime: Double = 32400 // 9 AM default
    
    @Environment(\.modelContext) private var modelContext
    @Query var bills: [Bill]
    @Query var incomes: [Income]
    @Query var debts: [Debt]
    @Query var recurringBills: [RecurringBill]
    @Query var recurringIncomes: [RecurringIncome]
    @Query var recurringDebts: [RecurringDebt]
    
    @State private var showWipeConfirmation = false
    
    let themes = ["System", "Light", "Dark"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $userTheme) {
                        ForEach(themes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Section 2: Notifications
                // Section 2: Notifications
                Section("Notifications") {
                    Toggle("Enable Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            if newValue {
                                NotificationManager.shared.requestPermission()
                            }
                            // Reschedule immediately
                            NotificationManager.shared.scheduleNotifications(context: modelContext)
                        }
                    
                    if notificationsEnabled {
                        DatePicker("Alert Time", selection: Binding(
                            get: { Date(timeIntervalSince1970: notificationTime) },
                            set: { notificationTime = $0.timeIntervalSince1970 }
                        ), displayedComponents: .hourAndMinute)
                        .onChange(of: notificationTime) { _, _ in
                             NotificationManager.shared.scheduleNotifications(context: modelContext)
                        }
                    }
                    
                    Text("Allows the app to remind you of upcoming bills.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Section 3: Data Management
                Section("Data Management") {
                    Button("Erase All Data", role: .destructive) {
                        showWipeConfirmation = true
                    }
                }
                
                // Section 4: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Mike Budget App")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Erase All Data?", isPresented: $showWipeConfirmation, titleVisibility: .visible) {
                Button("Erase Everything", role: .destructive) {
                    wipeAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. It will delete all bills, income, debts, and recurring rules.")
            }
        }
    }
    
    // requestPermission moved to Manager
    
    func wipeAllData() {
        // Delete all entities
        for item in bills { modelContext.delete(item) }
        for item in incomes { modelContext.delete(item) }
        for item in debts { modelContext.delete(item) }
        for item in recurringBills { modelContext.delete(item) }
        for item in recurringIncomes { modelContext.delete(item) }
        for item in recurringDebts { modelContext.delete(item) }
        
        // Save Context (optional, autosave usually handles it but good to be sure)
        try? modelContext.save()
    }
}
