import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: ExpensesViewModel

    var body: some View {
        List {
            ForEach(viewModel.data) { expenseGroup in
                Section(header: Text(Formatter.formatDate(expenseGroup.date))) {
                    ForEach(expenseGroup.expenses!) { expense in
                        NavigationLink(destination: ExpenseView(expense: expense)) {
                            ExpenseCellView(expense: expense)
                                .onAppear {
                                    self.expenseOnAppear(expense)
                                }
                        }
                    }
                    .onDelete { indexSet in
                        self.expensesOnDelete(at: indexSet, expenseGroupId: expenseGroup.id)
                    }
                }
                .textCase(.none)
            }
        }
        .navigationTitle("History")
        .navigationBarItems(trailing: EditButton())
        .listStyle(PlainListStyle())
    }

    private func expenseOnAppear(_ expense: Expense) {
        if viewModel.isLastExpense(expense) {
            viewModel.loadNextPage()
        }
    }
    
    private func expensesOnDelete(at indexSet: IndexSet, expenseGroupId: String) {
        var expensesToDelete = [Expense]()
        indexSet.forEach( { indexToDelete in
            let group = viewModel.data.first(where: {
                $0.id == expenseGroupId
            })
            expensesToDelete.append(group!.expenses[indexToDelete])
        })
        
        expensesToDelete.forEach( { expenseToDelete in
            viewModel.deleteExpense(expenseToDelete)
        })
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(ExpensesViewModel(data: testData))
            .environment(\.locale, .init(identifier: "zh"))
    }
}
