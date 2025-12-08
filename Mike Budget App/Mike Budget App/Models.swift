import Foundation
import SwiftData

// 1. BILLS
@Model
class Bill: Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var dueDate: Date
    var isPaid: Bool
    var category: String
    var frequency: String
    var recurrenceRuleID: UUID?
    var paidWith: String // <--- NEW FIELD
    
    init(name: String, amount: Double, dueDate: Date, category: String = "Bill", frequency: String = "One-Time", paidWith: String = "Cash") {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.isPaid = false
        self.category = category
        self.frequency = frequency
        self.paidWith = paidWith
    }
}

// 1.1 Recurring Bill Rule
@Model
class RecurringBill: Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var category: String
    var frequency: String
    var nextDueDate: Date
    var lastGeneratedDate: Date?
    var paidWith: String // <--- NEW FIELD
    
    init(name: String, amount: Double, nextDueDate: Date, category: String = "Bill", frequency: String = "Monthly", paidWith: String = "Cash") {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.nextDueDate = nextDueDate
        self.category = category
        self.frequency = frequency
        self.paidWith = paidWith
    }
}

// 2. INCOME (Updated with Date)
@Model
class Income: Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var frequency: String
    var type: String
    var dueDate: Date
    var isReceived: Bool // <--- NEW FIELD
    var recurrenceRuleID: UUID?
    
    init(name: String, amount: Double, frequency: String = "Monthly", type: String = "Static", dueDate: Date = Date(), isReceived: Bool = false) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.type = type
        self.dueDate = dueDate
        self.isReceived = isReceived
    }
}

// 2.1 Recurring Income Rule
@Model
class RecurringIncome: Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var frequency: String
    var type: String
    var nextDueDate: Date
    var lastGeneratedDate: Date?
    
    init(name: String, amount: Double, nextDueDate: Date, frequency: String = "Monthly", type: String = "Static") {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.type = type
        self.nextDueDate = nextDueDate
    }
    
    // NOTE: 1st and 15th logic will be handled by the Manager creating 2 separate rules or custom logic.
    // For simplicity now, we stick to standard frequencies in the model.
}

// 3. DEBTS
@Model
class Debt: Identifiable {
    var id: UUID
    var name: String
    var totalBalance: Double
    var minPayment: Double
    var dueDate: Date
    var frequency: String
    var isPaid: Bool
    var recurrenceRuleID: UUID?
    
    init(name: String, totalBalance: Double, minPayment: Double, dueDate: Date, frequency: String = "Monthly", isPaid: Bool = false) {
        self.id = UUID()
        self.name = name
        self.totalBalance = totalBalance
        self.minPayment = minPayment
        self.dueDate = dueDate
        self.frequency = frequency
        self.isPaid = isPaid
    }
}

// 3.1 Recurring Debt Rule
@Model
class RecurringDebt: Identifiable {
    var id: UUID
    var name: String
    var totalBalance: Double // Snapshot of balance when rule created? Or references a master debt?
    // For "Truck Payment", it's usually just a recurring payment.
    // The total balance might go down.
    // For simplicity, we just copy the fields to new instances.
    var minPayment: Double
    var nextDueDate: Date
    var frequency: String
    var lastGeneratedDate: Date?
    
    init(name: String, totalBalance: Double = 0, minPayment: Double, nextDueDate: Date, frequency: String = "Monthly") {
        self.id = UUID()
        self.name = name
        self.totalBalance = totalBalance
        self.minPayment = minPayment
        self.nextDueDate = nextDueDate
        self.frequency = frequency
    }
}
