import Foundation
import SQLite

class ExpensesViewModel: ObservableObject {
    // newest dates at the front
    @Published var data: [ExpenseGroup]
    @Published var categories: [String]
    @Published var expensesByCategory: [ExpenseCategory]
    @Published var expensesByTime: [ExpenseDate]
    @Published private(set) var hasMoreHistory = true
    @Published private(set) var historyPage = 0
    
    let db = DatabaseManager.sharedInstance.db
    let expensesTable = DatabaseManager.sharedInstance.expensesTable
    let targetsTable = DatabaseManager.sharedInstance.targetsTable

    static let pageSize = 50
    var dbOffset = 0
    
    init(data: [ExpenseGroup] = [], categories: [String] = []) {
        self.data = data
        self.categories = categories
        self.expensesByCategory = []
        self.expensesByTime = []
        
        if (data.isEmpty) {
            loadNextPage()
            loadCategories()
        }
    }

    var totalAnnualTarget: Double {
        do {
            guard let targetsTable = targetsTable else { return 0.0 }
            let total = try db?.scalar(targetsTable.select(annualTarget.sum))
            return total ?? 0.0
        } catch {
            return 0.0
        }
    }

    var dailyTarget: Double {
        totalAnnualTarget / 365.0
    }
    
    func loadExpensesByTime(fromDate: String, toDate: String) {
        var filteredTable: Table?
        
        filteredTable = expensesTable?
            .select(date, category, cost.sum)
            .filter(date >= fromDate)
            .filter(date <= toDate)
            .group(date, category)
            .order(date.asc)
        
        let expenses = try! db?.prepare(filteredTable!)
        
        var runningTotals = [String: Double]()
        expensesByTime = []
        
        var lastAddedDate: Date? = nil
        let calendar = Calendar.current

        for category in categories {
            runningTotals[category] = 0
        }
        
        for expense in expenses! {
            let expenseDate = Formatter.dateFromIso(expense[date])
            
            while lastAddedDate == nil || expenseDate != lastAddedDate! {
                var dateToAdd: Date
                
                if lastAddedDate == nil {
                    dateToAdd = expenseDate
                } else {
                    dateToAdd = calendar.date(byAdding: .day, value: 1, to: lastAddedDate!)!
                }
                
                for category in categories {
                    expensesByTime.append(ExpenseDate(date: dateToAdd, category: category, runningTotal: runningTotals[category]!))
                }
                
                lastAddedDate = dateToAdd
            }
            
            var runningTotalForCategory = runningTotals[expense[category]]
            runningTotalForCategory! += expense[cost.sum]!
            runningTotals.updateValue(runningTotalForCategory!, forKey: expense[category])
            
            var expenseTimeForCategory = expensesByTime.first(where: { $0.date == expenseDate && $0.category == expense[category ]})!
            expenseTimeForCategory.runningTotal = runningTotalForCategory!
        }
    }
    
    func loadExpensesByCategory(fromDate: String, toDate: String) {
        expensesByCategory.removeAll()
        
        let categoryQuery = expensesTable!
            .join(.leftOuter, targetsTable!, on: targetsTable![category] == expensesTable![category])
            .filter(date >= fromDate)
            .filter(date <= toDate)
            .select(cost.sum, expensesTable![category], annualTarget)
            .group(expensesTable![category])
            .order(expensesTable![category].asc)
        
        var mappedCategories = [String: ExpenseCategory]()
        if let categoryResult = try? db?.prepare(categoryQuery) {
            for c in categoryResult! {
                let name = c[category]
                let sum = c[cost.sum] ?? 0.0
                let annualTarget: Double? = c[annualTarget]
                mappedCategories[name] = ExpenseCategory(name: name, sum: sum, annualTarget: annualTarget)
            }
        }

        if let targetResults = try? db?.prepare(targetsTable!.select(category, annualTarget).order(category.asc)) {
            for row in targetResults! {
                let name = row[category]
                if mappedCategories[name] == nil {
                    mappedCategories[name] = ExpenseCategory(name: name, sum: 0.0, annualTarget: row[annualTarget])
                }
            }
        }

        expensesByCategory = mappedCategories.values.sorted { $0.name < $1.name }
    }
    
    func isLastExpense(_ expense: Expense) -> Bool {
        return expense.date == data.last!.date && expense.id == data.last!.expenses.last!.id
    }
    
    func loadCategories() {
        categories.removeAll()
        
        do {
            var categorySet = Set<String>()
            
            if let expenseCategories = try db?.prepare((expensesTable?.select(distinct: category))!) {
                for c in expenseCategories {
                    categorySet.insert(c[category])
                }
            }
            
            if let targetCategories = try db?.prepare((targetsTable?.select(distinct: category))!) {
                for c in targetCategories {
                    categorySet.insert(c[category])
                }
            }
            
            categories = categorySet.sorted()
            if categories.isEmpty {
                categories = ["Miscellaneous"]
            }
        } catch {
            print("Failed to fetch categories: \(error)")
            categories = ["Miscellaneous"]
        }
    }

    func saveAnnualTarget(_ target: Double?, for categoryName: String) {
        do {
            guard let targetsTable = targetsTable else { return }

            let row = targetsTable.filter(category == categoryName)
            if let target = target {
                let updated = try db?.run(row.update(annualTarget <- target)) ?? 0
                if updated == 0 {
                    try db?.run(targetsTable.insert(category <- categoryName, annualTarget <- target))
                }

                if let index = expensesByCategory.firstIndex(where: { $0.name == categoryName }) {
                    expensesByCategory[index].annualTarget = target
                } else {
                    expensesByCategory.append(ExpenseCategory(name: categoryName, sum: 0.0, annualTarget: target))
                    expensesByCategory.sort { $0.name < $1.name }
                }

                if !categories.contains(categoryName) {
                    categories.append(categoryName)
                    categories.sort()
                }
            } else {
                try db?.run(row.delete())

                if let index = expensesByCategory.firstIndex(where: { $0.name == categoryName }) {
                    if expensesByCategory[index].sum == 0.0 {
                        expensesByCategory.remove(at: index)
                    } else {
                        expensesByCategory[index].annualTarget = nil
                    }
                }

                if let expensesTable = expensesTable {
                    let expenseCount = try db?.scalar(expensesTable.filter(category == categoryName).count) ?? 0
                    if expenseCount == 0 {
                        categories.removeAll { $0 == categoryName }
                        if categories.isEmpty {
                            categories = ["Miscellaneous"]
                        }
                    }
                }
            }
        } catch {
            print("Save annual target failed: \(error)")
        }
    }
    
    func loadNextPage() {
        guard hasMoreHistory else { return }

        let nextPage: AnySequence<Row>!
        do {
            try nextPage = db?.prepare((expensesTable?.order(date.desc, id.desc).limit(ExpensesViewModel.pageSize, offset: dbOffset))!)
        } catch {
            print("Delete failed: \(error)")
            return
        }
    
        var loadedCount = 0
        for item in nextPage! {
            let expense = Expense(id: item[id], date: item[date], cost: item[cost], category: item[category], description: item[desc])
            addOrUpdateExpenseInMemory(expense)
            loadedCount += 1
        }
        if loadedCount < ExpensesViewModel.pageSize {
            hasMoreHistory = false
        }
        historyPage += 1
    }
    
    func updateExpense(_ expense: Expense) {
        do {
            let row = expensesTable?.filter(id == expense.id)
            try db?.run((row?.update(cost <- expense.cost, category <- expense.category, desc <- expense.desc, date <- expense.date))!)
            addOrUpdateExpenseInMemory(expense)
        } catch {
            print("Update failed: \(error)")
        }
    }
    
    func addExpense(_ expense: Expense) {
        do {
            try db?.run((expensesTable?.insert(cost <- expense.cost, category <- expense.category, desc <- expense.desc, date <- expense.date))!)
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
            if try db?.run((expensesTable?.filter(id == expense.id).delete())!) ?? 0 > 0 {
                
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
    var annualTarget: Double?
}

struct ExpenseDate: Identifiable {
    var id = UUID()
    
    var date: Date
    var category: String
    var runningTotal: Double
}
