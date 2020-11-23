import Foundation

struct ExpenseGroup: Identifiable {
    var id: String {
        return date
    }
    var date: String
    var expenses: [Expense]!
}

let testData = [
    ExpenseGroup(date: "2020-06-23", expenses: [
                    Expense(id: 3, date: "2020-06-24", cost: 12.00, category: "Food", description: "KFC"),
                    Expense(id: 2, date: "2020-06-23", cost: 10.00, category: "Food", description: "Big Mac")]),
    ExpenseGroup(date: "2020-06-20", expenses: [Expense(id: 1, date: "2020-06-20", cost: 2000.00, category: "Miscellaneous", description: "MacBook Pro")])
]
