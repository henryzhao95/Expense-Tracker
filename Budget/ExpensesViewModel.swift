import Foundation
import SQLite

class ExpensesViewModel: ObservableObject {
    // newest dates at the front
    @Published var data: [ExpenseGroup]
    @Published var categories: [String]
    @Published var expensesByCategory: [ExpenseCategory]
    @Published var expensesByTime: ([Date], [Double], [Double])
    
    let db = DatabaseManager.sharedInstance.db
    let table = DatabaseManager.sharedInstance.table
    
    static let pageSize = 50
    var dbOffset = 0
    
    init(data: [ExpenseGroup] = [], categories: [String] = []) {
        self.data = data
        self.categories = categories
        self.expensesByCategory = []
        self.expensesByTime = ([], [], [])
        
        if (data.isEmpty) {
            loadNextPage()
            loadCategories()
        }
    }
    
    func loadExpensesByTime(fromDate: String) {
        var dates: [Date] = []
        var actualRunningTotal: [Double] = []
        var targetRunningTotal: [Double] = []
        
        let today = Formatter.isoDate(Date())
        let filteredTable = table?
            .select(date, category, cost.sum)
            .filter(date >= fromDate)
            .filter(date <= today)
            .group(date, category)
            .order(date.asc)
        let expenses = try! db?.prepare(filteredTable!)
        
        // Hardcoded
        let dailyTarget = 16.9315
        
        let calendar = Calendar.current
        dates.append(Formatter.dateFromIso(fromDate))
        actualRunningTotal.append(0)
        targetRunningTotal.append(0)
        
        for expense in expenses! {
            let expenseDate = Formatter.dateFromIso(expense[date])
            while dates.last! < expenseDate {
                dates.append(calendar.date(byAdding: .day, value: 1, to: dates.last!)!)
                actualRunningTotal.append(actualRunningTotal.last ?? 0)
                targetRunningTotal.append((targetRunningTotal.last != nil) ? targetRunningTotal.last! + dailyTarget : dailyTarget)
            }
            
            actualRunningTotal[actualRunningTotal.count-1] += expense[cost.sum]!
        }
        
        expensesByTime = (dates, actualRunningTotal, targetRunningTotal)
    }
    
    func loadExpensesByCategory(fromDate: String) {
        expensesByCategory.removeAll()
        
        let today = Formatter.isoDate(Date())
        
        let categoryQuery = table?
            .filter(date >= fromDate)
            .filter(date <= today)
            .select(cost.sum, category)
            .group(category)
            .order(category.asc)
        
        let categoryResult = try! db?.prepare(categoryQuery!)
        for c in categoryResult! {
            let name = c[category]
            let sum = c[cost.sum]
            expensesByCategory.append(ExpenseCategory(name: name, sum: sum!))
        }
    }
    
    func isLastExpense(_ expense: Expense) -> Bool {
        return expense.date == data.last!.date && expense.id == data.last!.expenses.last!.id
    }
    
    func loadCategories() {
        do {
            let results = try db?.prepare((table?.select(distinct: category).order(date.desc))!)
            categories.removeAll()
            for c in results! {
                categories.append(c[category])
            }
            if categories.count == 0 {
                categories.append("Miscellaneous")
            }
        } catch {
            print("Failed to fetch categories: \(error)")
        }
    }
    
    func loadNextPage() {
        let nextPage: AnySequence<Row>!
        do {
            try nextPage = db?.prepare((table?.order(date.desc, id.desc).limit(ExpensesViewModel.pageSize, offset: dbOffset))!)
        } catch {
            print("Delete failed: \(error)")
            return
        }
    
        for item in nextPage! {
            let expense = Expense(id: item[id], date: item[date], cost: item[cost], category: item[category], description: item[desc])
            addOrUpdateExpenseInMemory(expense)
        }
    }
    
    func updateExpense(_ expense: Expense) {
        do {
            let row = table?.filter(id == expense.id)
            try db?.run((row?.update(cost <- expense.cost, category <- expense.category, desc <- expense.desc, date <- expense.date))!)
            addOrUpdateExpenseInMemory(expense)
        } catch {
            print("Update failed: \(error)")
        }
    }
    
    func addExpense(_ expense: Expense) {
        do {
            try db?.run((table?.insert(cost <- expense.cost, category <- expense.category, desc <- expense.desc, date <- expense.date))!)
            // Row ID to pass back
            expense.id = try db!.prepare("SELECT LAST_INSERT_ROWID()").next()![0]! as! Int64
            addOrUpdateExpenseInMemory(expense)
        } catch {
            print("Add expense failed: \(error)")
        }
    }
    
    private func addOrUpdateExpenseInMemory(_ expense: Expense) {
        var groupIndex = 0
        
        if !categories.contains(expense.category) {
            categories.insert(expense.category, at: 0)
        }
        
        if data.isEmpty || expense.date > data.first!.date { // adding to the start e.g. new expense
            groupIndex = 0
        } else if expense.date < data[data.count - 1].date { // adding to the end e.g. paging
            groupIndex = data.count
        } else { // adding in the middle
            while expense.date < data[groupIndex].date {
                groupIndex += 1
            }
        }
        
        if groupIndex == data.count || expense.date != data[groupIndex].date {
            let newExpenseGroup = ExpenseGroup(date: expense.date, expenses: [Expense]())
            data.insert(newExpenseGroup, at: groupIndex)
        }
        
        // Insert at top (newest) by default, ordered by date, then id
        var rowNumber = 0
        for (i, e) in data[groupIndex].expenses.enumerated() {
            if expense.id < e.id {
                rowNumber += 1
            } else if expense.id == e.id {
                data[groupIndex].expenses[i] = expense
                return // finished updating expense
            } else {
                break
            }
        }
        
        data[groupIndex].expenses.insert(expense, at: rowNumber)
        
        // TODO: fix bug where adding an old expense (that will not appear in the next database page) will lead to an offset mismatch
        dbOffset += 1
    }
    
    func deleteExpense(_ expense: Expense) {
        do {
            if try db?.run((table?.filter(id == expense.id).delete())!) ?? 0 > 0 {
                
                let sectionInMemoryIndex = data.firstIndex(where: {
                    $0.date == expense.date
                });
                if sectionInMemoryIndex != nil {
                    let expenseInMemoryIndex = data[sectionInMemoryIndex!].expenses.firstIndex(where: { $0.id == expense.id })
                    if expenseInMemoryIndex != nil {
                        data[sectionInMemoryIndex!].expenses?.remove(at: expenseInMemoryIndex!);
                    }
                    if data[sectionInMemoryIndex!].expenses.isEmpty {
                        data.remove(at: sectionInMemoryIndex!)
                    }
                    dbOffset -= 1
                }
            } else {
            }
        } catch {
            print("Delete failed: \(error)")
        }
    }
}

struct ExpenseCategory {
    var name: String
    var sum: Double
}
