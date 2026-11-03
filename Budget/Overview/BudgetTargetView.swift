import SwiftUI

struct BudgetTargetView: View {
    @EnvironmentObject var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss

    let category: String
    @State private var targetText: String

    init(category: String, initialTarget: Double?) {
        self.category = category
        _targetText = State(initialValue: Self.formatInitialTarget(initialTarget))
    }

    private static func formatInitialTarget(_ target: Double?) -> String {
        guard let target = target else { return "" }
        if target.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", target)
        } else {
            return String(format: "%.2f", target)
        }
    }

    private var parsedTarget: Double? {
        guard !targetText.isEmpty else { return nil }
        return Double(targetText)
    }

    private var isValidTarget: Bool {
        if targetText.isEmpty {
            return true
        }
        return parsedTarget != nil
    }

    var body: some View {
        Form {
            Section(header: Text("Category")) {
                Text(category)
                    .font(.headline)
            }

            Section(header: Text("Annual Budget")) {
                TextField("Enter annual budget", text: $targetText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }

            if let target = parsedTarget, target > 0 {
                Section(header: Text("Breakdown")) {
                    HStack {
                        Text("Monthly")
                        Spacer()
                        Text(Formatter.formatCost(target / 12.0))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Weekly")
                        Spacer()
                        Text(Formatter.formatCost(target / 52.0))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Daily")
                        Spacer()
                        Text(Formatter.formatCost(target / 365.0))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Button(action: saveTarget) {
                    Text("Save")
                }
                .disabled(!isValidTarget)

                if targetText.isEmpty {
                    Text("Leave blank to remove this budget target.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Button(role: .destructive, action: removeTarget) {
                        Text("Remove Budget")
                    }
                }
            }
        }
        .navigationTitle("Budget Target")
    }

    private func saveTarget() {
        let target = parsedTarget
        viewModel.saveAnnualTarget(target, for: category)
        dismiss()
    }

    private func removeTarget() {
        viewModel.saveAnnualTarget(nil, for: category)
        dismiss()
    }
}

struct BudgetTargetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BudgetTargetView(category: "Groceries", initialTarget: 6000.0)
                .environmentObject(ExpensesViewModel())
        }
    }
}
