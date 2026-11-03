import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: ExpensesViewModel
    @State var showExpenseView = false
    @State private var selectedCategory: String?

    private var filteredExpenseGroups: [FilteredExpenseGroup] {
        viewModel.data.compactMap { group in
            let expenses = group.expenses.filter {
                selectedCategory == nil || $0.category == selectedCategory
            }
            guard !expenses.isEmpty else { return nil }
            return FilteredExpenseGroup(group: group, expenses: expenses)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredExpenseGroups) { filteredGroup in
                Section(header: Text(Formatter.formatDate(filteredGroup.group.date))) {
                    ForEach(filteredGroup.expenses) { expense in
                        NavigationLink(destination: ExpenseView(expense: expense, isActive: $showExpenseView)) {
                            ExpenseCellView(expense: expense)
                                .onAppear {
                                    self.expenseOnAppear(expense)
                                }
                        }
                    }
                    .onDelete { indexSet in
                        self.expensesOnDelete(at: indexSet, expenses: filteredGroup.expenses)
                    }
                }
                .textCase(.none)
            }

            if selectedCategory != nil && viewModel.hasMoreHistory {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        viewModel.loadNextPage()
                    }
                    .id(viewModel.historyPage)
            }
        }
        .navigationTitle("History")
        .navigationBarItems(trailing: HStack {
            Menu {
                Button {
                    selectedCategory = nil
                } label: {
                    if selectedCategory == nil {
                        Label("All Categories", systemImage: "checkmark")
                    } else {
                        Text("All Categories")
                    }
                }

                ForEach(viewModel.categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        if selectedCategory == category {
                            Label(category, systemImage: "checkmark")
                        } else {
                            Text(category)
                        }
                    }
                }
            } label: {
                Label(selectedCategory ?? "Category", systemImage: "line.3.horizontal.decrease.circle")
            }
            EditButton()
        })
        .listStyle(PlainListStyle())
    }

    private func expenseOnAppear(_ expense: Expense) {
        if viewModel.isLastExpense(expense) {
            viewModel.loadNextPage()
        }
    }
    
    private func expensesOnDelete(at indexSet: IndexSet, expenses: [Expense]) {
        let expensesToDelete = indexSet.map { expenses[$0] }
        expensesToDelete.forEach( { expenseToDelete in
            viewModel.deleteExpense(expenseToDelete)
        })
    }
}

private struct FilteredExpenseGroup: Identifiable {
    let group: ExpenseGroup
    let expenses: [Expense]

    var id: String { group.id }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(ExpensesViewModel(data: testData))
            .environment(\.locale, .init(identifier: "zh"))
    }
}
