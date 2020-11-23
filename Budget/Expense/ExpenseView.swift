import SwiftUI

struct ExpenseView: View {
    @EnvironmentObject var viewModel: ExpensesViewModel
    @State private var category: String = ""
    @State private var date = Date()
    @State private var description = ""
    @State private var cost: Double = 0
    // id 0 = new expense
    @State private var id: Int64 = 0
    
    var costProxy: Binding<String> {
        Binding<String>(
            get: { self.string(from: self.cost) },
            set: {
                if let value = Formatter.currencyFormatter.number(from: $0) {
                    self.cost = value.doubleValue
                }
            }
        )
    }
    private func string(from value: Double) -> String {
        guard let s = Formatter.currencyFormatter.string(from: NSNumber(value: value)) else { return "" }
        return s
    }
    
    init(expense: Expense? = nil) {
        if (expense != nil) {
            _id = State(initialValue: expense!.id as Int64)
            _cost = State(initialValue: expense!.cost)
            _date = State(initialValue: Formatter.dateFromIso(expense!.date))
            _category = State(initialValue: expense!.category)
            _description = State(initialValue: expense!.desc ?? "")
        }
    }
    
    var body: some View {
        return VStack {
            Form {
                // TODO: allow selecting, what happens when there's no categories?
                CategoryPickerView(categories: viewModel.categories, selectedCategory: $category)
                
                DatePicker("Date", selection: $date, displayedComponents: .date)
                
                TextField("Description", text: $description)
                
                // can't directly use formatter: Formatter.currencyFormatter overload https://stackoverflow.com/questions/56799456/swiftui-textfield-with-formatter-not-working
                TextField("Cost", text: costProxy)
                    .multilineTextAlignment(.trailing)
                    .font(.title)
                    .foregroundColor(.red)
                    .keyboardType(.decimalPad)
                
                HStack {
                    Spacer()
                    Button(action: saveExpense) {
                        Text("Save")
                    }
                }
            }
            .resignKeyboardOnDragGesture()
            .onAppear {
                if id == 0 { // new expense
                    if viewModel.categories.count > 0 {
                        category = viewModel.categories[0]
                    } else {
                        category = "Miscellaneous"
                    }
                }
            }
        }
        .navigationTitle("Expense")
    }
    
    func saveExpense() {
        let expense = Expense(id: id, date: Formatter.isoDate(date), cost: cost, category: category, description: description)
        
        if expense.id > 0 {
            viewModel.updateExpense(expense)
        } else {
            viewModel.addExpense(expense)
            // TODO: return to HistoryViewModel
        }
    }
}

struct ExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseView()
            .environmentObject(ExpensesViewModel(data: testData))
        // .environment(\.locale, .init(identifier: "zh"))
    }
}

extension UIApplication {
    func endEditing(_ force: Bool) {
        self.windows
            .filter{$0.isKeyWindow}
            .first?
            .endEditing(force)
    }
}

struct ResignKeyboardOnDragGesture: ViewModifier {
    var gesture = DragGesture().onChanged{_ in
        UIApplication.shared.endEditing(true)
    }
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

extension View {
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
}
