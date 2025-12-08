import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query var bills: [Bill]
    @Query var incomes: [Income]
    @Query var debts: [Debt]
    
    // State to track which month we are viewing (defaults to today)

    // State to track which month we are viewing (defaults to today)
    @EnvironmentObject var navState: NavigationState
    
    // --- 1. Filter Logic ---
    
    // Helper to check if a date is in the selected month
    // Helper to check if a date is in the selected month
    func isSelectedMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: navState.selectedMonth, toGranularity: .month)
    }
    
    // Filtered Totals
    var monthlyIncome: Double {
        incomes.filter { isSelectedMonth($0.dueDate) }
               .reduce(0) { $0 + $1.amount }
    }
    
    var monthlyExpenses: Double {
        let billTotal = bills.filter { isSelectedMonth($0.dueDate) }
                             .reduce(0) { $0 + $1.amount }
        // For Debts, we track the Minimum Payment
        let debtTotal = debts.filter { isSelectedMonth($0.dueDate) }
                             .reduce(0) { $0 + $1.minPayment }
        return billTotal + debtTotal
    }
    
    var netAmount: Double {
        monthlyIncome - monthlyExpenses
    }
    
    // --- 2. Unified Upcoming List Logic ---
    
    // A temporary struct to hold either a Bill or a Debt for display
    struct UpcomingItem: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
        let dueDate: Date
        let isDebt: Bool
    }
    
    var combinedUpcoming: [UpcomingItem] {
        // 1. Get Bills for this month that are NOT paid
        let billItems = bills.filter { !$0.isPaid && isSelectedMonth($0.dueDate) }
                             .map { UpcomingItem(name: $0.name, amount: $0.amount, dueDate: $0.dueDate, isDebt: false) }
        
        // 2. Get Debts for this month that are NOT paid
        let debtItems = debts.filter { !$0.isPaid && isSelectedMonth($0.dueDate) }
                             .map { UpcomingItem(name: $0.name, amount: $0.minPayment, dueDate: $0.dueDate, isDebt: true) }
        
        // 3. Combine and Sort by Date
        return (billItems + debtItems).sorted { $0.dueDate < $1.dueDate }
    }
    
    // --- 3. Interface ---
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MONTH SWITCHER
                    HStack {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2)
                        }
                        
                        Text(navState.selectedMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.headline)
                            .frame(width: 150)
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2)
                        }
                    }
                    .padding(.bottom)
                    
                    // NET CARD
                    VStack(spacing: 10) {
                        Text("Net Remaining")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(netAmount, format: .currency(code: "USD"))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(netAmount >= 0 ? .green : .red)
                        
                        Text("Income: \(monthlyIncome.formatted(.currency(code: "USD")))  •  Expenses: \(monthlyExpenses.formatted(.currency(code: "USD")))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // BREAKDOWN TABLE
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monthly Breakdown")
                            .font(.headline)
                        
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
                            // Filter valid items for this month first to be efficient
                            let monthBills = bills.filter { isSelectedMonth($0.dueDate) }
                            let monthDebts = debts.filter { isSelectedMonth($0.dueDate) }
                            
                            ForEach(paymentMethods, id: \.self) { method in
                                breakdownRow(method: method, bills: monthBills, debts: monthDebts)
                            }
                            
                            Divider()
                            
                            // Total Row
                            totalRow(bills: monthBills, debts: monthDebts)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // UPCOMING BILLS & DEBTS SECTION
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Upcoming Expenses (\(navState.selectedMonth.formatted(.dateTime.month(.wide))))")
                            .font(.headline)
                        
                        if combinedUpcoming.isEmpty {
                            Text("No unpaid bills or debts for this month.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical)
                        } else {
                            ForEach(combinedUpcoming) { item in
                                HStack {
                                    // Icon to differentiate (Orange Card for Debt, default for Bill)
                                    Image(systemName: item.isDebt ? "creditcard.fill" : "doc.text.fill")
                                        .foregroundStyle(item.isDebt ? .orange : .blue)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.name).font(.subheadline).bold()
                                        Text(item.dueDate.formatted(date: .numeric, time: .omitted))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.amount, format: .currency(code: "USD"))
                                }
                                .padding()
                                .background(Color(uiColor: .systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Overview")
        }
    }
    
    func changeMonth(by value: Int) {
        navState.changeMonth(by: value)
    }
    
    // Helper View Builders for Breakdown Logic
    @ViewBuilder
    func breakdownRow(method: String, bills: [Bill], debts: [Debt]) -> some View {
        // 1. Calculate Bills portion
        let methodBills = bills.filter { ($0.paidWith == method) || ($0.paidWith.isEmpty && method == "Cash") }
        let billAssigned = methodBills.reduce(0) { $0 + $1.amount }
        let billPaid = methodBills.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
        
        // 2. Calculate Debts portion (ONLY for Cash)
        let debtAssigned = (method == "Cash") ? debts.reduce(0) { $0 + $1.minPayment } : 0
        let debtPaid = (method == "Cash") ? debts.filter { $0.isPaid }.reduce(0) { $0 + $1.minPayment } : 0
        
        let assigned = billAssigned + debtAssigned
        let paid = billPaid + debtPaid
        let remaining = assigned - paid
        
        GridRow {
            Text(method.replacingOccurrences(of: "CC-", with: "")).font(.caption)
            Text(assigned, format: .currency(code: "USD")).font(.caption)
            Text(paid, format: .currency(code: "USD")).font(.caption).foregroundStyle(.green)
            Text(remaining, format: .currency(code: "USD")).font(.caption).foregroundStyle(remaining > 0 ? .red : .secondary)
        }
    }
    
    @ViewBuilder
    func totalRow(bills: [Bill], debts: [Debt]) -> some View {
        let totalBillsAssigned = bills.reduce(0) { $0 + $1.amount }
        let totalDebtsAssigned = debts.reduce(0) { $0 + $1.minPayment }
        let totalAssigned = totalBillsAssigned + totalDebtsAssigned
        
        let totalBillsPaid = bills.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
        let totalDebtsPaid = debts.filter { $0.isPaid }.reduce(0) { $0 + $1.minPayment }
        let totalPaid = totalBillsPaid + totalDebtsPaid
        
        let totalRemaining = totalAssigned - totalPaid
        
        GridRow {
            Text("Total").bold()
            Text(totalAssigned, format: .currency(code: "USD")).bold()
            Text(totalPaid, format: .currency(code: "USD")).bold().foregroundStyle(.green)
            Text(totalRemaining, format: .currency(code: "USD")).bold().foregroundStyle(.red)
        }
    }
}
