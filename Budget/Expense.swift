import UIKit

class Expense: Identifiable {
    
    var id: Int64
    var date: String
    var cost: Double
    var category: String
    var desc: String?
        
    init(id: Int64 = 0, date: String, cost: Double = 0, category: String, description: String? = nil) {
        self.id = id
        self.date = date
        self.cost = cost
        self.category = category
        self.desc = description
    }
}
