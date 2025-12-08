import SwiftUI
import SwiftData

struct IncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Income.dueDate) var incomes: [Income]
    @Query var recurringRules: [RecurringIncome]
    
    @State private var showAddSheet = false
    @State private var searchText = ""
    @EnvironmentObject var navState: NavigationState
    
    @State private var itemToDelete: Income?
    @State private var showDeleteConfirmation = false
    
    var visibleIncomes: [Income] {
        let calendar = Calendar.current
        let today = Date()
        // Logic: Show exactly the selected month
        let start = navState.selectedMonth.startOfMonth
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        
        let dateFiltered = incomes.filter { $0.dueDate >= start && $0.dueDate < nextMonth }
        
        if searchText.isEmpty {
            return dateFiltered
        } else {
            return dateFiltered.filter { income in
                income.name.localizedCaseInsensitiveContains(searchText) ||
                income.type.localizedCaseInsensitiveContains(searchText) ||
                income.frequency.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // State managed by NavigationState

    
    var body: some View {
        NavigationStack {
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
                
                // Monthly Total
                Section {
                    HStack {
                        Text("Monthly Total")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(visibleIncomes.reduce(0) { $0 + $1.amount }, format: .currency(code: "USD"))
                            .font(.headline)
                            .bold()
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Text("Monthly Received")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(visibleIncomes.filter { $0.isReceived }.reduce(0) { $0 + $1.amount }, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.blue)
                    }
                }
                
                ForEach(visibleIncomes) { income in
                    NavigationLink(destination: EditIncomeView(income: income)) {
                        HStack {
                            Image(systemName: income.isReceived ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(income.isReceived ? .green : .gray)
                                .font(.title2)
                                .onTapGesture {
                                    income.isReceived.toggle()
                                }
                            
                            VStack(alignment: .leading) {
                                Text(income.name).font(.headline)
                                Text(income.dueDate.formatted(date: .numeric, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(income.amount, format: .currency(code: "USD"))
                                Text(income.type).font(.caption2).foregroundStyle(income.type == "Variable" ? .orange : .gray)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
                
                // Removed Load More Button
            }
            .navigationTitle("Income")
            .toolbar {
                Button(action: { showAddSheet = true }) { Label("Add", systemImage: "plus") }
            }
            .sheet(isPresented: $showAddSheet) {
                AddIncomeSheet(startDate: Calendar.current.isDate(Date(), equalTo: navState.selectedMonth, toGranularity: .month) ? Date() : navState.selectedMonth)
            }
            .confirmationDialog("Delete Recurring Income?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete This Entry Only", role: .destructive) {
                    if let item = itemToDelete { modelContext.delete(item) }
                }
                Button("Delete Future Entries Also", role: .destructive) {
                    if let item = itemToDelete, let ruleID = item.recurrenceRuleID {
                        if let rule = recurringRules.first(where: { $0.id == ruleID }) {
                            modelContext.delete(rule)
                        }
                        modelContext.delete(item)
                        let expectedFuture = incomes.filter { $0.recurrenceRuleID == ruleID && $0.dueDate >= item.dueDate }
                        for future in expectedFuture { modelContext.delete(future) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Start/Stop Recurring?")
            }
            .searchable(text: $searchText, prompt: "Search income")
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        // Simple approach: Delete instance, if it has a rule, ask via Alert.
        if let index = offsets.first {
            let income = visibleIncomes[index]
            if income.recurrenceRuleID != nil {
                itemToDelete = income
                showDeleteConfirmation = true
            } else {
                modelContext.delete(income)
            }
        }
    }
}

// --- ADD INCOME SHEET (With 1st & 15th Logic) ---
struct AddIncomeSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var name = ""
    @State private var amount = 0.0
    @State private var type = "Static"
    @State private var frequency = "Monthly"
    @State private var startDate: Date
    
    let types = ["Static", "Variable"]
    let frequencies = ["One-Time", "Monthly", "Bi-Weekly", "1st and 15th"]
    
    init(startDate: Date) {
        _startDate = State(initialValue: startDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Source Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                }
                Section("Schedule") {
                    DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { Text($0) }
                    }
                }
                if frequency != "One-Time" {
                    Text("Auto-generates for next 3 months.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Income")
            .toolbar {
                Button("Save") {
                    saveIncome()
                    dismiss()
                }
            }
        }
    }
    
    func saveIncome() {
        if frequency != "One-Time" {
             // Create Recurring Rule
             // Note: For "1st and 15th", we might need two rules or the manager to handle it.
             // Manager logic for "Monthly" is simple. for "1st and 15th", let's handle it as 2 rules?
             // Or simpler: The RecurringManager logic I wrote handles standard frequencies.
             // If user selected "1st and 15th", let's make it two separate "Monthly" rules for now to keep it robust?
             // Actually, my manager only supports Weekly/Bi-Weekly/Monthly/Yearly.
             // Let's degrade 1st/15th to "Two Monthly Rules" strategy for simpler implementation in Manager,
             // OR update Manager to support custom days.
             // "Two Monthly Rules" is easiest and most robust for now.
             
             if frequency == "1st and 15th" {
                 // Rule 1: 1st of month
                 let calendar = Calendar.current
                 
                 // Find next 1st
                 var date1 = startDate
                 let day = calendar.component(.day, from: startDate)
                 if day > 1 {
                     // Move to next month 1st
                     date1 = calendar.date(byAdding: .month, value: 1, to: startDate)!
                     date1 = calendar.date(from: calendar.dateComponents([.year, .month], from: date1))! // set to 1st
                 }
                 let rule1 = RecurringIncome(name: name + " (1st)", amount: amount/2, nextDueDate: date1, frequency: "Monthly", type: type)
                 
                 // Rule 2: 15th of month
                 var date2 = startDate
                 if day > 15 {
                      // Move to next month 15th
                      date2 = calendar.date(byAdding: .month, value: 1, to: startDate)!
                 } else {
                     // Stay in current month if before 15th? Or if today is 10th, 15th is coming.
                 }
                 // Force day to 15
                 var comps = calendar.dateComponents([.year, .month], from: date2)
                 comps.day = 15
                 date2 = calendar.date(from: comps)!
                 if date2 < startDate {
                     // If we calculated a past date, move to next month
                     date2 = calendar.date(byAdding: .month, value: 1, to: date2)!
                 }
                 
                 let rule2 = RecurringIncome(name: name + " (15th)", amount: amount/2, nextDueDate: date2, frequency: "Monthly", type: type)
                 
                 modelContext.insert(rule1)
                 modelContext.insert(rule2)
                 
             } else {
                 let newRule = RecurringIncome(name: name, amount: amount, nextDueDate: startDate, frequency: frequency, type: type)
                 modelContext.insert(newRule)
             }
             
             RecurringManager.shared.processRecurringItems(context: modelContext)
             
        } else {
             // One Time
             let newIncome = Income(name: name, amount: amount, frequency: frequency, type: type, dueDate: startDate)
             modelContext.insert(newIncome)
        }
    }
}

struct EditIncomeView: View {
    @Bindable var income: Income
    let types = ["Static", "Variable"]
    
    var body: some View {
        Form {
            TextField("Name", text: $income.name)
            TextField("Amount", value: $income.amount, format: .currency(code: "USD"))
            DatePicker("Received Date", selection: $income.dueDate, displayedComponents: .date)
            Toggle("Mark as Received", isOn: $income.isReceived)
            Picker("Type", selection: $income.type) {
                ForEach(types, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
        }
        .navigationTitle("Edit Income")
    }
}
