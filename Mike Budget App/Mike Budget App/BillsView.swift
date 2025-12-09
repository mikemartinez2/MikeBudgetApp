import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bill.dueDate) var bills: [Bill]
    // Fetch rules to potentially list them or manage them? For now, we manage via deletion of instances.
    @Query var recurringRules: [RecurringBill] 
    
    @State private var showAddSheet = false
    @State private var searchText = ""
    @EnvironmentObject var navState: NavigationState
    
    // For Deletion Confirmation
    @State private var itemToDelete: Bill?
    @State private var showDeleteConfirmation = false
    
    // --- 1. Filter Logic (View Logic) ---
    var visibleBills: [Bill] {
        let calendar = Calendar.current
        let today = Date()
        
        // Logic: Show exactly the selected month
        // We use strict start/end range
        let start = navState.selectedMonth.startOfMonth
        // endOfMonth gives us the Day at 00:00. 
        // We want anything LESS than the start of NEXT month.
        // Or we can say >= startOfMonth AND < startOfNextMonth
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        
        let dateFiltered = bills.filter { $0.dueDate >= start && $0.dueDate < nextMonth }
        
        if searchText.isEmpty {
            return dateFiltered
        } else {
            return dateFiltered.filter { bill in
                bill.name.localizedCaseInsensitiveContains(searchText) ||
                bill.category.localizedCaseInsensitiveContains(searchText) ||
                bill.paidWith.localizedCaseInsensitiveContains(searchText) ||
                bill.frequency.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // State now managed by NavigationState

    
    // --- 2. The List Interface ---
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
                    .buttonStyle(.borderless) // Critical for buttons inside List
                    .padding(.vertical, 5)
                }
                
                // Breakdown Table
                Section {
                    Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 8) {
                        // Header
                        GridRow {
                            Text("Method").bold()
                            Text("Assigned").bold()
                            Text("Paid").bold()
                            Text("Remaining").bold()
                        }
                        Divider()
                        
                        // Rows
                        let paymentMethods = ["AMEX", "USAA", "Bonvoy", "Discover", "CapitalOne", "Chase", "Barclays", "Apple", "Cash"]
                        
                        ForEach(paymentMethods, id: \.self) { method in
                            // Filter bills for this method
                            let methodBills = visibleBills.filter { ($0.paidWith == method) || ($0.paidWith.isEmpty && method == "Cash") } // Handle migration for empty
                            let assigned = methodBills.reduce(0) { $0 + $1.amount }
                            let paid = methodBills.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
                            let remaining = assigned - paid
                            
                            // Only show row if there is activity? Or always show? User asked for table with these options.
                            // I'll show rows that have non-zero assigned to avoid clutter, or maybe all?
                            // User request: "replace with a table that has these options". Implies showing all or at least the structure.
                            // Showing all might be tall (9 rows). Let's show all for now as requested.
                            
                            GridRow {
                                Text(method.replacingOccurrences(of: "CC-", with: "")).font(.caption)
                                Text(assigned, format: .currency(code: "USD")).font(.caption)
                                Text(paid, format: .currency(code: "USD")).font(.caption).foregroundStyle(.green)
                                Text(remaining, format: .currency(code: "USD")).font(.caption).foregroundStyle(remaining > 0 ? .red : .secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Total Row
                        GridRow {
                            Text("Total").bold()
                            Text(visibleBills.reduce(0) { $0 + $1.amount }, format: .currency(code: "USD")).bold()
                            Text(visibleBills.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }, format: .currency(code: "USD")).bold().foregroundStyle(.green)
                            Text((visibleBills.reduce(0) { $0 + $1.amount } - visibleBills.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }), format: .currency(code: "USD")).bold().foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // The Bill List
                ForEach(visibleBills) { bill in
                    NavigationLink(destination: EditBillView(bill: bill)) {
                        HStack {
                            Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(bill.isPaid ? .green : .gray)
                                .font(.title2)
                                .onTapGesture {
                                    bill.isPaid.toggle()
                                }
                            
                            VStack(alignment: .leading) {
                                Text(bill.name)
                                    .font(.headline)
                                Text(bill.dueDate.formatted(date: .numeric, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(bill.amount, format: .currency(code: "USD"))
                        }
                    }
                }
                .onDelete(perform: deleteItems)
                
                // The "Load More" Button removed in favor of pagination arrows
            }
            .navigationTitle("Bills")
            .toolbar {
                Button(action: { showAddSheet = true }) {
                    Label("Add Bill", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddBillSheet(dueDate: Calendar.current.isDate(Date(), equalTo: navState.selectedMonth, toGranularity: .month) ? Date() : navState.selectedMonth)
            }
            .confirmationDialog("Delete Recurring Bill?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete This Bill Only", role: .destructive) {
                    if let item = itemToDelete {
                        modelContext.delete(item)
                    }
                }
                Button("Delete Future Bills Too", role: .destructive) {
                    if let item = itemToDelete, let ruleID = item.recurrenceRuleID {
                        // Delete the rule
                        if let rule = recurringRules.first(where: { $0.id == ruleID }) {
                            modelContext.delete(rule)
                        }
                        // Delete this item
                        modelContext.delete(item)
                        // Future items handling:
                        let expectedFuture = bills.filter { $0.recurrenceRuleID == ruleID && $0.dueDate >= item.dueDate }
                        for future in expectedFuture {
                             modelContext.delete(future)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is a recurring bill. Do you want to delete just this entry, or stop all future bills?")
            }
            .searchable(text: $searchText, prompt: "Search bills")
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        // Just identify the item to delete. 
        // We can't use withAnimation directly if we need to show a sheet, 
        // but for swipe-to-delete we might need to be careful.
        // Simple approach: Delete instance, if it has a rule, ask via Alert.
        
        if let index = offsets.first {
            let bill = visibleBills[index]
            if bill.recurrenceRuleID != nil {
                // It's recurring
                itemToDelete = bill
                showDeleteConfirmation = true
            } else {
                // Standard delete
                modelContext.delete(bill)
            }
        }
    }
}

// --- 3. Add Bill Sheet (With Recurring Logic Restored) ---
struct AddBillSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var name = ""
    @State private var amount = 0.0
    @State private var dueDate: Date // 1. Removed "= Date()"
    @State private var frequency = "One-Time"
    @State private var paidWith = "Cash"
    
    let frequencies = ["One-Time", "Weekly", "Bi-Weekly", "Bi-Monthly", "Quarterly", "Monthly"]
    let paymentMethods = ["AMEX", "USAA", "Bonvoy", "Discover", "CapitalOne", "Chase", "Barclays", "Apple", "Cash"]
    
    // 2. Added this custom initializer to accept the date
    init(dueDate: Date) {
        _dueDate = State(initialValue: dueDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bill Details") {
                    TextField("Bill Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
                
                Section("Schedule") {
                    DatePicker("Starting Date", selection: $dueDate, displayedComponents: .date)
                    
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Paid With", selection: $paidWith) {
                        ForEach(paymentMethods, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }
                
                if frequency != "One-Time" {
                    Section {
                        Text("This will create a recurring bill that automatically generates for future dates until you delete it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Bill")
            .toolbar {
                Button("Save") {
                    saveBills()
                    dismiss()
                }
            }
        }
    }
    
    func saveBills() {
        if frequency != "One-Time" {
            let newRule = RecurringBill(name: name, amount: amount, nextDueDate: dueDate, frequency: frequency, paidWith: paidWith)
            modelContext.insert(newRule)
            RecurringManager.shared.processRecurringItems(context: modelContext)
        } else {
            let newBill = Bill(name: name, amount: amount, dueDate: dueDate, frequency: frequency, paidWith: paidWith)
            modelContext.insert(newBill)
        }
    }
}
    
// --- 4. Edit View ---
struct EditBillView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query var bills: [Bill] // Needed to fetch future bills
    @Query var recurringRules: [RecurringBill]
    
    let bill: Bill // Changed from Bindable to let
    
    // Local State for buffering edits
    @State private var name = ""
    @State private var amount = 0.0
    @State private var dueDate = Date()
    @State private var frequency = "One-Time"
    @State private var paidWith = "Cash"
    @State private var isPaid = false
    
    @State private var showUpdateOptions = false
    
    let frequencies = ["One-Time", "Weekly", "Bi-Weekly", "Bi-Monthly", "Quarterly", "Monthly"]
    let paymentMethods = ["AMEX", "USAA", "Bonvoy", "Discover", "CapitalOne", "Chase", "Barclays", "Apple", "Cash"]
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Bill Name", text: $name)
                TextField("Amount", value: $amount, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                
                Picker("Paid With", selection: $paidWith) {
                    ForEach(paymentMethods, id: \.self) { Text($0) }
                }
            }
            
            Section("Schedule") {
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                
                Picker("Frequency", selection: $frequency) {
                    ForEach(frequencies, id: \.self) { Text($0) }
                }
                
                Toggle("Mark as Paid", isOn: $isPaid)
            }
        }
        .navigationTitle("Edit Bill")
        .navigationBarBackButtonHidden(true) // We are controlling the save manually
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if bill.recurrenceRuleID != nil {
                        showUpdateOptions = true
                    } else {
                        saveThisOnly()
                    }
                }
            }
        }
        .onAppear {
            name = bill.name
            amount = bill.amount
            dueDate = bill.dueDate
            frequency = bill.frequency
            paidWith = bill.paidWith
            isPaid = bill.isPaid
        }
        .confirmationDialog("Update Recurring Bill?", isPresented: $showUpdateOptions, titleVisibility: .visible) {
            Button("Update This Bill Only") {
                saveThisOnly()
            }
            Button("Update Future Bills Also") {
                saveFutureAlso()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is a recurring bill. Do you want to update just this entry, or all future bills?")
        }
    }
    
    func saveThisOnly() {
        bill.name = name
        bill.amount = amount
        bill.dueDate = dueDate
        bill.frequency = frequency
        bill.paidWith = paidWith
        bill.isPaid = isPaid
        dismiss()
    }
    
    func saveFutureAlso() {
        // 1. Update this bill
        bill.name = name
        bill.amount = amount
        bill.dueDate = dueDate
        bill.frequency = frequency
        bill.paidWith = paidWith
        bill.isPaid = isPaid
        
        guard let ruleID = bill.recurrenceRuleID else {
            dismiss()
            return
        }
        
        // 2. Update the Rule
        if let rule = recurringRules.first(where: { $0.id == ruleID }) {
            rule.name = name
            rule.amount = amount
            rule.frequency = frequency
            rule.paidWith = paidWith
            // We don't necessarily update nextDueDate unless logic requires it, usually we leave the schedule unless user forces it.
        }
        
        // 3. Update Future Bills
        // Fetch all bills with this ruleID that have a dueDate > this bill's OLD dueDate? Or simply > today?
        // Usually "Future" means relative to the item being edited.
        // It's safer to say: Update all bills linked to this ruleID that are AFTER this bill's current DueDate.
        
        let futureBills = bills.filter { $0.recurrenceRuleID == ruleID && $0.dueDate > bill.dueDate }
        for futureBill in futureBills {
            futureBill.name = name
            futureBill.amount = amount
            futureBill.frequency = frequency
            futureBill.paidWith = paidWith
            // Don't update isPaid or Date generally, unless we wanted to shift everything.
            // Shifting dates is complex. Let's stick to properties.
        }
        
        dismiss()
    }
}

// --- 5. Date Helpers (Required for the filters to work) ---
// Note: If you already put this in DebtView, you don't strictly need it here again,
// but keeping it here ensures this file is self-contained and won't crash.
//extension Date {
//    var startOfMonth: Date {
//        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
//    }
//    var endOfMonth: Date {
//        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth)!
//    }
//}
