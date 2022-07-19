import Charts
import SwiftUI
import Charts

struct ExpenseChartView : View {
    @EnvironmentObject var viewModel: ExpensesViewModel
    
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(viewModel.expensesByTime) { expenseDate in
                    AreaMark(
                        x: .value("Date", expenseDate.date),
                        y: .value("Spent", expenseDate.runningTotal),
                        stacking: .standard
                    )
                    .foregroundStyle(by: .value("Category", expenseDate.category))
                    
                }
                if (viewModel.expensesByTime.count > 1) {
                    LineMark(x: .value("Date", viewModel.expensesByTime[0].date), y: .value("Spent", 0.0))
                    LineMark(x: .value("Date", viewModel.expensesByTime[viewModel.expensesByTime.count-1].date), y: .value("Spent", 18.082 * Double(Calendar.current.dateComponents([.day], from: viewModel.expensesByTime[0].date, to: viewModel.expensesByTime[viewModel.expensesByTime.count-1].date).day!)))
                }
            }
            .padding()
        } else {
            // Fallback on earlier versions
        }
    }
}

struct Line_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseChartView()
            .environmentObject(ExpensesViewModel(data: testData))
    }
}
