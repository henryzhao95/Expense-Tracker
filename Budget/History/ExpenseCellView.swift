import SwiftUI

struct ExpenseCellView: View {
    var expense: Expense
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(expense.category)
                    .font(.body)
                if expense.desc != nil {
                    Text(expense.desc!)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(Formatter.formatCost(expense.cost))
                .foregroundColor(.red)
        }
    }
}

struct ExpenseCellView_Previews: PreviewProvider {
   static var previews: some View {
    ExpenseCellView(expense: Expense(id: 1, date: "2020-06-22", cost: 10.00, category: "Food", description: "Dinner"))
   }
}
