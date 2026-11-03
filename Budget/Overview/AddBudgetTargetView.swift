import SwiftUI

struct AddBudgetTargetView: View {
    @EnvironmentObject var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var categoryName: String = ""
    @State private var targetText: String = ""

    private var parsedTarget: Double? {
        guard !targetText.isEmpty else { return nil }
        return Double(targetText)
    }

    private var isValid: Bool {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let target = parsedTarget, target > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    TextField("Category Name", text: $categoryName)
                        .autocapitalization(.words)
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
            }
            .navigationTitle("New Budget Target")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    save()
                }
                .disabled(!isValid)
            )
        }
    }

    private func save() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let target = parsedTarget else { return }
        viewModel.saveAnnualTarget(target, for: trimmedName)
        dismiss()
    }
}

struct AddBudgetTargetView_Previews: PreviewProvider {
    static var previews: some View {
        AddBudgetTargetView()
            .environmentObject(ExpensesViewModel())
    }
}
