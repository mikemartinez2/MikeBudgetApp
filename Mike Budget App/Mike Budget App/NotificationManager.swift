import Foundation
import UserNotifications
import SwiftData
import SwiftUI

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notifications authorized")
            } else if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotifications(context: ModelContext) {
        // 1. Check if enabled
        @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false
        @AppStorage("notificationTime") var notificationTime: Double = 32400 // Default 9:00 AM (9 * 3600)
        
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        
        // 2. Clear existing
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 3. Fetch Items
        do {
            let billDescriptor = FetchDescriptor<Bill>(predicate: #Predicate { !$0.isPaid })
            let bills = try context.fetch(billDescriptor)
            
            let debtDescriptor = FetchDescriptor<Debt>(predicate: #Predicate { !$0.isPaid })
            let debts = try context.fetch(debtDescriptor)
            
            // 4. Schedule
            let calendar = Calendar.current
            let timeDate = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "notificationTime"))
            let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
            
            var scheduleCount = 0
            let limit = 60 // System limit is 64
            
            // Allow scheduling for today if time hasn't passed? Or just strictly future?
            // Let's say future or today.
            let now = Date()
            
            // Combine and sort by date
            struct AlertItem {
                let id: UUID
                let title: String
                let body: String
                let date: Date
            }
            
            var items: [AlertItem] = []
            
            for bill in bills {
                items.append(AlertItem(id: bill.id, title: "Bill Due: \(bill.name)", body: "Amount: \(bill.amount.formatted(.currency(code: "USD")))", date: bill.dueDate))
            }
            
            for debt in debts {
                items.append(AlertItem(id: debt.id, title: "Debt Payment Due: \(debt.name)", body: "Min Payment: \(debt.minPayment.formatted(.currency(code: "USD")))", date: debt.dueDate))
            }
            
            // Sort by date ascending
            items.sort { $0.date < $1.date }
            
            for item in items {
                if scheduleCount >= limit { break }
                
                // Construct Trigger Date
                var triggerComps = calendar.dateComponents([.year, .month, .day], from: item.date)
                triggerComps.hour = timeComponents.hour
                triggerComps.minute = timeComponents.minute
                
                guard let triggerDate = calendar.date(from: triggerComps) else { continue }
                
                // Only schedule if in future
                if triggerDate > now {
                    let content = UNMutableNotificationContent()
                    content.title = item.title
                    content.body = item.body
                    content.sound = .default
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
                    let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("Error scheduling \(item.title): \(error)")
                        }
                    }
                    scheduleCount += 1
                }
            }
            
            print("Scheduled \(scheduleCount) notifications.")
            
        } catch {
            print("Failed to fetch items for notifications: \(error)")
        }
    }
}
