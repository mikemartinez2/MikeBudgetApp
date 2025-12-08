import SwiftUI
import Combine

class NavigationState: ObservableObject {
    @Published var selectedMonth: Date = Date()
    
    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}
