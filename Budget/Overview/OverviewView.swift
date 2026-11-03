import SwiftUI

struct DateFrame: Equatable {
    let title: String
    let fromDate: Date
    let toDate: Date

    var budgetDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: fromDate)
        let end = calendar.startOfDay(for: toDate)
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }
}

private enum OverviewSheet: Identifiable {
    case addBudget
    case customDateRange

    var id: Self { self }
}

struct OverviewView: View {
    @EnvironmentObject var viewModel: ExpensesViewModel

    @State private var dateFrame: DateFrame?
    @State private var activeSheet: OverviewSheet?

    var body: some View {
        VStack {
            List {
                ForEach(viewModel.expensesByCategory, id: \.self.name) { expenseCategory in
                    NavigationLink(destination: BudgetTargetView(category: expenseCategory.name, initialTarget: expenseCategory.annualTarget)) {
                        CategoryCellView(expenseCategory: expenseCategory, budgetDays: dateFrame?.budgetDays)
                            .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(PlainListStyle())

            ExpenseChartView()
        }
        .navigationTitle("Overview")
        .navigationBarItems(
            leading: Button(action: { activeSheet = .addBudget }) {
                Image(systemName: "plus")
            },
            trailing: Menu {
                Button("4 Weeks") {
                    selectRecentRange(weeks: 4, title: NSLocalizedString("4 Weeks", comment: "Last four weeks"))
                }
                Button("13 Weeks") {
                    selectRecentRange(weeks: 13, title: NSLocalizedString("13 Weeks", comment: "Last thirteen weeks"))
                }
                Button("FY to Date") {
                    selectFinancialYearToDate()
                }
                Button("Custom Dates…") {
                    activeSheet = .customDateRange
                }
            } label: {
                HStack(spacing: 4) {
                    Text(dateFrame.map(displayTitle(for:)) ?? NSLocalizedString("Date Range", comment: "Date range selector"))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
            }
        )
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addBudget:
                AddBudgetTargetView()
                    .environmentObject(viewModel)
            case .customDateRange:
                CustomDateRangeView(
                    initialStartDate: dateFrame?.fromDate ?? Calendar.current.date(byAdding: .day, value: -27, to: Date())!,
                    initialEndDate: dateFrame?.toDate ?? Date(),
                    onApply: { startDate, endDate in
                        selectDateRange(
                            title: nil,
                            fromDate: startDate,
                            toDate: endDate
                        )
                    }
                )
            }
        }
        .onAppear {
            if dateFrame == nil {
                selectFinancialYearToDate()
            }
        }
    }

    private func selectRecentRange(weeks: Int, title: String) {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: endDate)!
        selectDateRange(title: title, fromDate: startDate, toDate: endDate)
    }

    private func selectFinancialYearToDate() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.month, .year], from: today)
        let year = components.year!
        let financialYearStart = DateComponents(
            year: components.month! <= 6 ? year - 1 : year,
            month: 7,
            day: 1
        )
        let startDate = calendar.date(from: financialYearStart)!
        selectDateRange(
            title: NSLocalizedString("FY to Date", comment: "Financial year to date"),
            fromDate: startDate,
            toDate: today
        )
    }

    private func selectDateRange(title: String?, fromDate: Date, toDate: Date) {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: fromDate)
        let endDate = calendar.startOfDay(for: toDate)
        guard startDate <= endDate else { return }

        dateFrame = DateFrame(title: title ?? "", fromDate: startDate, toDate: endDate)
        viewModel.loadExpensesByCategory(
            fromDate: Formatter.isoDate(startDate),
            toDate: Formatter.isoDate(endDate)
        )
        viewModel.loadExpensesByTime(
            fromDate: Formatter.isoDate(startDate),
            toDate: Formatter.isoDate(endDate)
        )
    }

    private func displayTitle(for frame: DateFrame) -> String {
        guard !frame.title.isEmpty else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: frame.fromDate)) – \(formatter.string(from: frame.toDate))"
        }
        return frame.title
    }
}

private struct CustomDateRangeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var endDate: Date
    let onApply: (Date, Date) -> Void

    init(initialStartDate: Date, initialEndDate: Date, onApply: @escaping (Date, Date) -> Void) {
        _startDate = State(initialValue: initialStartDate)
        _endDate = State(initialValue: initialEndDate)
        self.onApply = onApply
    }

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Start Date", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .navigationTitle("Custom Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Apply") {
                    onApply(startDate, endDate)
                    dismiss()
                }
            )
        }
    }
}

struct OverviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OverviewView()
                .environmentObject(ExpensesViewModel(data: testData))
        }
    }
}
