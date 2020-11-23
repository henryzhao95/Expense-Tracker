import Charts
import SwiftUI

struct ExpenseChartView : UIViewRepresentable {
    @EnvironmentObject var viewModel: ExpensesViewModel
    
    // typealias UIViewType = LineChartView
    private let lineChartFormatter = LineChartFormatter()
    
    init() {
    }

    func makeUIView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        chartView.chartDescription?.text = ""
        chartView.leftAxis.enabled = false
        chartView.rightAxis.drawGridLinesEnabled = false
        chartView.rightAxis.setLabelCount(5, force: true)
        chartView.rightAxis.axisMinimum = 0
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.xAxis.setLabelCount(5, force: true)
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.valueFormatter = lineChartFormatter
        chartView.drawBordersEnabled = false
        chartView.dragEnabled = false
        chartView.legend.enabled = false
        updateUIView(chartView, context: context)
        return chartView
    }
    
    private func getChartDataSets() -> [LineChartDataSet] {
        let (dates, actualRunningTotal, targetRunningTotal) = viewModel.expensesByTime
        lineChartFormatter.data = dates.map { Formatter.isoDate($0) }
        
        var spendingChartDataEntries = [ChartDataEntry]()
        var budgetedChartDataEntries = [ChartDataEntry]()
        
        // TODO: x axis dates (like January 17th rather than 2000-01-17)
        for i in 0 ..< dates.count {
            let x = XAxis()
            x.valueFormatter = lineChartFormatter
            spendingChartDataEntries.append(ChartDataEntry(x: Double(i), y: actualRunningTotal[i]))
            budgetedChartDataEntries.append(ChartDataEntry(x: Double(i), y: targetRunningTotal[i]))
        }
        
        let spendingChartDataSet = LineChartDataSet(entries: spendingChartDataEntries, label: "Cumulative Spending")
        spendingChartDataSet.colors = [UIColor.red]
        spendingChartDataSet.fill = Fill.fillWithColor(.red)
        spendingChartDataSet.drawFilledEnabled = true
        spendingChartDataSet.drawCirclesEnabled = false
        spendingChartDataSet.drawValuesEnabled = false
        
        let budgetedChartDataSet = LineChartDataSet(entries: budgetedChartDataEntries, label: "Budgeted Spending")
        budgetedChartDataSet.lineWidth = 5;
        budgetedChartDataSet.colors = [UIColor.purple]
        budgetedChartDataSet.drawCirclesEnabled = false
        budgetedChartDataSet.drawValuesEnabled = false
        
        var chartDataSets = [LineChartDataSet]()
        chartDataSets.append(spendingChartDataSet)
        chartDataSets.append(budgetedChartDataSet)

        return chartDataSets
    }
    
    func updateUIView(_ uiView: LineChartView, context: Context) {
        uiView.data = LineChartData(dataSets: getChartDataSets())
        uiView.animate(xAxisDuration: 0.2, yAxisDuration: 0.2, easingOption: .easeInCubic)
    }
}

public class LineChartFormatter: NSObject, IAxisValueFormatter {
    var data: [String]!
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if value >= 0 && value < Double(data.count) {
            return data[Int(value)]
        } else {
            return ""
        }
    }
}

struct Line_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseChartView()
            .environmentObject(ExpensesViewModel(data: testData))
    }
}
