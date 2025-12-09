import Foundation
import SwiftData

@MainActor
class RecurringManager {
    static let shared = RecurringManager()
    
    private init() {}
    
    func processRecurringItems(context: ModelContext) {
        processRecurringBills(context: context)
        processRecurringIncome(context: context)
        processRecurringDebts(context: context)
        
        do {
            try context.save()
        } catch {
            print("Failed to save context after processing recurring items: \(error)")
        }
    }
    
    // MARK: - Bills
    private func processRecurringBills(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<RecurringBill>()
            let rules = try context.fetch(descriptor)
            let today = Date()
            // Generate out to 6 months
            let futureLimit = Calendar.current.date(byAdding: .month, value: 24, to: today)!
            
            for rule in rules {
                var nextDate = rule.nextDueDate
                
                while nextDate <= futureLimit {
                    // Create concrete Bill
                    let newBill = Bill(
                        name: rule.name,
                        amount: rule.amount,
                        dueDate: nextDate,
                        category: rule.category,
                        frequency: rule.frequency,
                        paidWith: rule.paidWith
                    )
                    newBill.recurrenceRuleID = rule.id
                    context.insert(newBill)
                    
                    // Advance date
                    nextDate = calculateNextDate(from: nextDate, frequency: rule.frequency)
                }
                
                // Update rule state
                rule.nextDueDate = nextDate
                rule.lastGeneratedDate = Date()
            }
        } catch {
            print("Error processing recurring bills: \(error)")
        }
    }
    
    // MARK: - Income
    private func processRecurringIncome(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<RecurringIncome>()
            let rules = try context.fetch(descriptor)
            let today = Date()
            let futureLimit = Calendar.current.date(byAdding: .month, value: 24, to: today)!
            
            for rule in rules {
                var nextDate = rule.nextDueDate
                
                while nextDate <= futureLimit {
                    let newIncome = Income(
                        name: rule.name,
                        amount: rule.amount,
                        frequency: rule.frequency,
                        type: rule.type,
                        dueDate: nextDate
                    )
                    newIncome.recurrenceRuleID = rule.id
                    context.insert(newIncome)
                    
                    nextDate = calculateNextDate(from: nextDate, frequency: rule.frequency)
                }
                
                rule.nextDueDate = nextDate
                rule.lastGeneratedDate = Date()
            }
        } catch {
            print("Error processing recurring income: \(error)")
        }
    }
    
    // MARK: - Debt
    private func processRecurringDebts(context: ModelContext) {
        // Debt is tricky. Usually "Recurring Debt" isn't a new debt every month,
        // but rather a recurring *payment* or just a reminder.
        // However, based on user request "Truck Payment = $700... keeps that as an every month debt",
        // it sounds like they want a monthly entry to track that specific payment obligation.
        // So we will treat it like a Bill basically.
        
        do {
            let descriptor = FetchDescriptor<RecurringDebt>()
            let rules = try context.fetch(descriptor)
            let today = Date()
            let futureLimit = Calendar.current.date(byAdding: .month, value: 24, to: today)!
            
            for rule in rules {
                var nextDate = rule.nextDueDate
                
                while nextDate <= futureLimit {
                    let newDebt = Debt(
                        name: rule.name,
                        totalBalance: rule.totalBalance, // This might be static or decremented? valid q.
                        minPayment: rule.minPayment,
                        dueDate: nextDate,
                        frequency: rule.frequency
                    )
                    newDebt.recurrenceRuleID = rule.id
                    context.insert(newDebt)
                    
                    nextDate = calculateNextDate(from: nextDate, frequency: rule.frequency)
                }
                
                rule.nextDueDate = nextDate
                rule.lastGeneratedDate = Date()
            }
        } catch {
            print("Error processing recurring debts: \(error)")
        }
    }
    
    // MARK: - Helpers
    private func calculateNextDate(from date: Date, frequency: String) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case "Weekly":
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case "Bi-Weekly":
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case "Monthly":
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case "Bi-Monthly":
            return calendar.date(byAdding: .month, value: 2, to: date) ?? date
        case "Quarterly":
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case "Yearly":
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        default:
            // Fallback to monthly if unknown, to avoid infinite loops or unchanged dates
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
}
