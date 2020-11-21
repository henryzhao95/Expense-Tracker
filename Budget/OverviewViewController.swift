//
//  OverviewViewController.swift
//  Budget
//
//  Created by Henry Zhao on 25/02/2016.
//  Copyright © 2016 Henry Zhao. All rights reserved.
//

import UIKit
import SQLite
import Charts

class OverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ChartViewDelegate {
    
    struct ExpenseCategory {
        var name: String
        var sum: Double
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var chartView: LineChartView!
    let lcf = LineChartFormatter()
    var data = [ExpenseCategory]()
    var categoryToChart: String? = nil;
    
    /*
     Time frame for the Overview
     Used like a rotating list, where [0] is current
     (Month, 2016-02-01)
     */
    var dateFrames = [(String, String)]()
    var selectedIndex: Int? = nil
    
    // "2016-02-01", used by reloadData() to restrict SQLite query
    var fromDate: String!
    
    let db = DatabaseManager.sharedInstance.db
    let table = DatabaseManager.sharedInstance.table
    
    @IBOutlet weak var navItem: UINavigationItem!
    var dateBarButton: UIBarButtonItem!
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        dateBarButton = UIBarButtonItem(title: "", style: .plain, target: self, action: #selector(toggleDateFrame))
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        
        chartView.delegate = self
        chartView.chartDescription?.text = ""
        chartView.leftAxis.enabled = false
        chartView.rightAxis.drawGridLinesEnabled = false
        chartView.rightAxis.setLabelCount(5, force: true)
        chartView.rightAxis.axisMinimum = 0
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.xAxis.setLabelCount(5, force: true)
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.valueFormatter = lcf
        chartView.drawBordersEnabled = false
        chartView.dragEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        dateBarButton.possibleTitles = reloadDateFrames()
        dateBarButton.title = dateFrames.first?.0
        navItem.rightBarButtonItem = dateBarButton
        
        reloadData()
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: NSNotification.Name(rawValue: "UIContentSizeCategoryDidChangeNotification"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func contentSizeCategoryDidChange() {
        tableView.reloadData() // adjust row height
    }
    
    // MARK: Date frames
    
    func reloadDateFrames() -> Set<String> {
        dateFrames.removeAll()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd" // for SQLite call
        
        let date = Date()
        let cal = Calendar.current
        let components = (cal as NSCalendar).components([.day, .month, .year], from: date)
        
        fromDate = df.string(from: date.addingTimeInterval(-29*24*60*60)) // + today
        dateFrames.append(("28 " + NSLocalizedString("Days", comment: "Days"), fromDate))
        
        let tempDate = df.string(from: date.addingTimeInterval(-90*24*60*60)) // + today
        dateFrames.append(("91 " + NSLocalizedString("Days", comment: "Days"), tempDate))
        
        var fyStart = components.year!
        if components.month! <= 6 { // 2016-02 is in 2015-16
            fyStart = fyStart - 1 // financial year
        }
        let fyString = String(describing: fyStart) + "-07-01"
        let fyEnd = fyStart % 100 + 1
        let fyTitle = String(describing: fyStart) + "-" + String(fyEnd) + " " + NSLocalizedString("FY", comment: "Financial Year")
        dateFrames.append((fyTitle, fyString))
        
        // for UIBarItem to calculate width required
        var categoryTitles = Set<String>()
        for dateFrame in dateFrames {
            categoryTitles.insert(dateFrame.0)
        }
        return categoryTitles
    }
    
    func toggleDateFrame() {
        dateFrames.append(dateFrames.removeFirst())
        
        dateBarButton.title = dateFrames.first?.0
        fromDate = dateFrames.first?.1
        navItem.rightBarButtonItem = dateBarButton
        
        reloadData()
        tableView.reloadData()
    }
    
    // Re-query database
    func reloadData() {
        data.removeAll()
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd" // for SQLite call
        let today = df.string(from: Date())
        
        let categoryQuery = table?
            .filter(date >= fromDate)
            .filter(date <= today)
            .select(cost.sum, category)
            .group(category)
            .order(category.asc)
        
        let categoryResult = try! db?.prepare(categoryQuery!)
        for c in categoryResult! {
            let name = c[category]
            let sum = c[cost.sum]
            data.append(ExpenseCategory(name: name, sum: sum!))
        }
        setChartData()
    }
    
    // MARK: LineChartView
    
    func setChartData() {
        let methodStart = NSDate()

        var dates: [Date] = []
        var actualRunningTotal: [Double] = []
        var targetRunningTotal: [Double] = []
        
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        let today = df.string(from: Date())
        let filteredTable = table?
            .select(date, category, cost.sum)
            .filter(date >= fromDate)
            .filter(date <= today)
            .group(date, category)
            .order(date.asc)
      let expenses = try! db?.prepare(filteredTable!)
        
        // Hardcoded
        let dailyTarget = 20.712
        
        let calendar = Calendar.current
        dates.append(df.date(from: fromDate)!)
        actualRunningTotal.append(0)
        targetRunningTotal.append(0)
        
        for expense in expenses! {
            let expenseDate = df.date(from: expense[date])!
            while dates.last! < expenseDate {
                dates.append(calendar.date(byAdding: .day, value: 1, to: dates.last!)!)
                actualRunningTotal.append(actualRunningTotal.last ?? 0)
                targetRunningTotal.append((targetRunningTotal.last != nil) ? targetRunningTotal.last! + dailyTarget : dailyTarget)
            }
            
            actualRunningTotal[actualRunningTotal.count-1] += expense[cost.sum]!
        }
        lcf.data = dates.map { df.string(from: $0) }
        
        var spendingChartDataEntries = [ChartDataEntry]()
        var budgetedChartDataEntries = [ChartDataEntry]()
        // TODO: x axis dates (like January 17th rather than 2000-01-17)
        for i in 0 ..< dates.count {
            let x = XAxis()
            x.valueFormatter = lcf
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
        
        chartView.data = LineChartData(dataSets: chartDataSets)
        chartView.animate(xAxisDuration: 0.2, yAxisDuration: 0.2, easingOption: .easeInCubic)
        
        let methodFinish = NSDate()
        let executionTime = methodFinish.timeIntervalSince(methodStart as Date)
        print("Execution time: \(executionTime)")
    }
    
    public class LineChartFormatter: NSObject, IAxisValueFormatter {
        var data: [String]!
        public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            return data[Int(value)]
        }
    }
    
    // MARK: UITableView
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count + 1 // + 1 for footer total
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExpenseCategoryCell", for: indexPath)
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        
        if indexPath.row == data.count {
            cell.textLabel?.text = ""
            var total = 0.0
            for category in data {
                total += category.sum
            }
            cell.detailTextLabel?.text = nf.string(from: NSNumber(value: total))
        } else {
            // Footer total
            cell.textLabel?.text = data[indexPath.row].name
            cell.detailTextLabel?.text = nf.string(from: NSNumber(value: data[indexPath.row].sum as Double))
        }
        
        cell.imageView?.image = UIImage(named: cell.textLabel!.text!.lowercased())
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.first!
    }
}
