import SwiftUI
import SwiftData

struct DebtView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Debt.dueDate) var debts: [Debt]
    @Query var recurringRules: [RecurringDebt]
    
    @State private var showAddSheet = false
    

    @State private var searchText = ""
    @State private var itemToDelete: Debt?
    @State private var showDeleteConfirmation = false
    
    // Pagination: How many months into the future to show?
    @EnvironmentObject var navState: NavigationState
    
    var totalDebtBalance: Double {
        // Deduplicate recurring debts to avoid inflating total balance
        let nonRecurring = debts.filter { $0.recurrenceRuleID == nil }
        let ruleIDs = Set(debts.compactMap { $0.recurrenceRuleID })
        var recurringSum = 0.0
        
        for id in ruleIDs {
            // Find one instance (e.g. the one closests to today or just the first one found) to represent the debt
            if let representation = debts.first(where: { $0.recurrenceRuleID == id }) {
                recurringSum += representation.totalBalance
            }
        }
        
        // Sum non-recurring
        let nonRecurringSum = nonRecurring.reduce(0) { $0 + $1.totalBalance }
        
        return nonRecurringSum + recurringSum
    }
    
    // Filter items based on how many months we have "expanded"
    var visibleDebts: [Debt] {
        let calendar = Calendar.current
        let today = Date()
        // End date increases as we click "Show Next Month"
        // Logic: Show exactly the selected month
        let start = navState.selectedMonth.startOfMonth
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        
        let dateFiltered = debts.filter { $0.dueDate >= start && $0.dueDate < nextMonth }
        
        if searchText.isEmpty {
            return dateFiltered
        } else {
            return dateFiltered.filter { debt in
                debt.name.localizedCaseInsensitiveContains(searchText) ||
                debt.frequency.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // State managed by NavigationState

    
    var body: some View {
        NavigationStack {
            VStack {
                // TOTAL DEBT LOAD CARD
                VStack(alignment: .leading, spacing: 10) {
                    Text("Total Debt Load")
                        .font(.headline).foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "creditcard.trianglebadge.exclamationmark")
                            .font(.title).foregroundStyle(.red)
                        Text(totalDebtBalance, format: .currency(code: "USD"))
                            .font(.title).bold()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                
                List {
                     // Month Switcher
                    Section {
                        ZStack {
                            HStack {
                                Button(action: { navState.changeMonth(by: -1) }) {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.title2)
                                }
                                Spacer()
                                Button(action: { navState.changeMonth(by: 1) }) {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.title2)
                                }
                            }
                            
                            Text(navState.selectedMonth.formatted(.dateTime.month(.wide).year()))
                                .font(.headline)
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 5)
                    }
                    
                    // Monthly Total Min Payments
                    Section {
                        HStack {
                            Text("Monthly Min Payments")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        Text(visibleDebts.reduce(0) { $0 + $1.minPayment }, format: .currency(code: "USD"))
                                .font(.headline)
                                .bold()
                        }
                        HStack {
                            Text("Monthly Paid")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(visibleDebts.filter { $0.isPaid }.reduce(0) { $0 + $1.minPayment }, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.green)
                        }
                    }
                    
                    ForEach(visibleDebts) { debt in
                        NavigationLink(destination: EditDebtView(debt: debt)) {
                            HStack {
                                Image(systemName: debt.isPaid ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(debt.isPaid ? .green : .gray)
                                    .font(.title2)
                                    .onTapGesture { debt.isPaid.toggle() }
                                
                                VStack(alignment: .leading) {
                                    Text(debt.name).font(.headline)
                                    Text("Due: \(debt.dueDate.formatted(date: .numeric, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(debt.minPayment, format: .currency(code: "USD")).bold()
                                    Text("Min Due").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                    
                    // Removed Load More
                }
            }
            .navigationTitle("Debts")
            .toolbar {
                Button(action: { showAddSheet = true }) { Label("Add Debt", systemImage: "plus") }
            }
            .sheet(isPresented: $showAddSheet) {
                AddDebtSheet(dueDate: Calendar.current.isDate(Date(), equalTo: navState.selectedMonth, toGranularity: .month) ? Date() : navState.selectedMonth)
            }
            .confirmationDialog("Delete Recurring Debt?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete This Entry Only", role: .destructive) {
                    if let item = itemToDelete { modelContext.delete(item) }
                }
                Button("Delete Future Entries Also", role: .destructive) {
                    if let item = itemToDelete, let ruleID = item.recurrenceRuleID {
                        if let rule = recurringRules.first(where: { $0.id == ruleID }) {
                            modelContext.delete(rule)
                        }
                        modelContext.delete(item)
                        let expectedFuture = debts.filter { $0.recurrenceRuleID == ruleID && $0.dueDate >= item.dueDate }
                        for future in expectedFuture { modelContext.delete(future) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Start/Stop Recurring?")
            }
            .searchable(text: $searchText, prompt: "Search debts")
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        if let index = offsets.first {
            let debt = visibleDebts[index]
            if debt.recurrenceRuleID != nil {
                itemToDelete = debt
                showDeleteConfirmation = true
            } else {
                modelContext.delete(debt)
                NotificationManager.shared.scheduleNotifications(context: modelContext)
            }
        }
    }
}

// Helpers for Date math
extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }
    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth)!
    }
}

// The Add Sheet (Retaining your previous format)
struct AddDebtSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var name = ""
    @State private var minPayment = 0.0
    @State private var totalBalance = 0.0
    @State private var dueDate: Date // Removed default value
    @State private var frequency = "Monthly"
    let frequencies = ["One-Time", "Weekly", "Bi-Weekly", "Monthly", "Yearly"]

    // Add this init
    init(dueDate: Date) {
        _dueDate = State(initialValue: dueDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Minimum Payment Details") {
                    TextField("Payment Name", text: $name)
                    TextField("Min Payment Amount", value: $minPayment, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
                Section {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { Text($0) }
                    }
                }
                Section {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                Section("Total Debt Remaining") {
                    TextField("Total Balance", value: $totalBalance, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad).foregroundStyle(.red)
                }
            }
            .navigationTitle("New Debt")
            .toolbar {
                Button("Save") {
                    if frequency != "Monthly" && frequency != "One-Time" && frequency != "Yearly" && frequency != "Bi-Weekly" && frequency != "Weekly" {
                        // Fallback
                    }
                    
                    // Simple frequency check? The picker gives strings.
                    // If logic differs, we can expand. But basic logic:
                    
                    // Note: User didn't ask explicitly for "Recurring Debt" toggle, but implied "keeps that as an every month debt". 
                    // So we assume everything added here is potentially recurring?
                    // The UI has "Frequency". "Monthly" implies recurring.
                    // But looking at original code... it just had the field.
                    
                    // Let's assume if Frequency != "One-Time" (which isn't in original list, but I should add it?), it's recurring.
                    // Original list: ["Weekly", "Bi-Weekly", "Monthly", "Yearly"] -> All recurring.
                    // I should add "One-Time" to the list to allow non-recurring debts.
                    
                    if frequency != "One-Time" {
                         let newRule = RecurringDebt(name: name, totalBalance: totalBalance, minPayment: minPayment, nextDueDate: dueDate, frequency: frequency)
                         modelContext.insert(newRule)
                         RecurringManager.shared.processRecurringItems(context: modelContext)
                    } else {
                         let newDebt = Debt(name: name, totalBalance: totalBalance, minPayment: minPayment, dueDate: dueDate, frequency: frequency)
                         modelContext.insert(newDebt)
                    }
                    try? modelContext.save()
                    NotificationManager.shared.scheduleNotifications(context: modelContext)
                    dismiss()
                }
            }
        }
    }
}

// The Edit View
struct EditDebtView: View {
    @Bindable var debt: Debt
    let frequencies = ["Weekly", "Bi-Weekly", "Monthly", "Yearly"]
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $debt.name)
                TextField("Min Payment", value: $debt.minPayment, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
            }
            Section {
                Picker("Frequency", selection: $debt.frequency) {
                    ForEach(frequencies, id: \.self) { Text($0) }
                }
            }
            Section("Total Balance") {
                TextField("Balance", value: $debt.totalBalance, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
            }
            Section {
                DatePicker("Due Date", selection: $debt.dueDate, displayedComponents: .date)
            }
        }
        .navigationTitle("Edit Debt")
    }
}
