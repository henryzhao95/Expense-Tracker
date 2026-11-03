import SwiftUI

struct CategoryCellView: View {
    var expenseCategory: ExpenseCategory
    var budgetDays: Int? = nil

    private var proratedBudget: Double? {
        guard let target = expenseCategory.annualTarget else { return nil }
        guard let days = budgetDays else { return nil }
        return target * (Double(days) / 365.0)
    }

    private var budgetAmount: Double? {
        guard let target = expenseCategory.annualTarget else { return nil }
        return proratedBudget ?? target
    }

    var body: some View {
        HStack {
            Text(expenseCategory.name)
                .font(.title2)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let budgetAmount = budgetAmount {
                    if #available(iOS 16.0, *) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                actualAmount
                                budgetLabel(for: budgetAmount)
                            }
                            VStack(alignment: .trailing, spacing: 2) {
                                actualAmount
                                budgetLabel(for: budgetAmount)
                            }
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            actualAmount
                            budgetLabel(for: budgetAmount)
                        }
                    }
                } else {
                    actualAmount
                    Text("Set Budget")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var actualAmount: some View {
        Text(Formatter.formatCost(expenseCategory.sum))
            .foregroundColor(.red)
            .font(.title3)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func budgetLabel(for amount: Double) -> some View {
        Text(formatBudget(amount))
            .font(.body)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func formatBudget(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount.rounded())) ?? "?"
    }
}

struct CategoryCellView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CategoryCellView(
                expenseCategory: ExpenseCategory(name: "Groceries", sum: 350.0, annualTarget: 6000.0),
                budgetDays: 28
            )
            CategoryCellView(
                expenseCategory: ExpenseCategory(name: "Entertainment", sum: 50.0, annualTarget: nil),
                budgetDays: 28
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
