import SwiftUI

@main
struct BudgetApp: App {
    @StateObject private var expensesViewModel = ExpensesViewModel()
    @State private var selection = 1
    @State private var expenseViewActive = true

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selection) {
                NavigationView {
                    OverviewView()
                }
                .tabItem{
                    Image(systemName: "chart.bar")
                    Text("Overview")
                }
                .tag(0)
                
                NavigationView {
                    ExpenseView(isActive: $expenseViewActive)
                }
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Expense")
                }
                .tag(1)
                
                NavigationView {
                    HistoryView()
                }
                .tabItem {
                    Image(systemName: "list.dash")
                    Text("History")
                }
                .tag(2)
            }
            .accentColor(.red)
            .environmentObject(expensesViewModel)
            .onChange(of: expenseViewActive, perform: { value in
                if expenseViewActive == false {
                    selection = 2
                    expenseViewActive = true
                }
            })
        }
    }
    
    func switchTabToHistoryView() {
        selection = 2
    }
}

