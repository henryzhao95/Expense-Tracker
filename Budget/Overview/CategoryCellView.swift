import SwiftUI

struct CategoryCellView: View {
    var expenseCategory: ExpenseCategory

    var body: some View {
        HStack {
            Text(expenseCategory.name)
                .font(.title2)
            Spacer()
            VStack {
                Text(Formatter.formatCost(expenseCategory.sum))
                    .foregroundColor(.red)
                    .font(.title3)
                
                Text(expenseCategory.annualTarget != nil ? Formatter.formatCost(expenseCategory.annualTarget!) : "?")
                    .font(.body)
            }
        }
    }
}

struct CategoryCellView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryCellView(expenseCategory: ExpenseCategory(name: "Test", sum: 20.5, annualTarget: nil))
    }
}
