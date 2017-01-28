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
    
    /*
     Time frame for the Overview
     Used like a rotating list, where [0] is current
     (Month, 2016-02-01)
     */
    var dateFrames = [(String, String)]()
    
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
        tableView.rowHeight = UITableViewAutomaticDimension
        
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
        // chartView.xAxis.wordWrapEnabled = true
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
        
        fromDate = df.string(from: date.addingTimeInterval(-30*24*60*60))
        dateFrames.append(("30 " + NSLocalizedString("Days", comment: "Days"), fromDate))
        
        let tempDate = df.string(from: date.addingTimeInterval(-90*24*60*60))
        dateFrames.append(("90 " + NSLocalizedString("Days", comment: "Days"), tempDate))
        
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
        let categoryQuery = table?.select(distinct: category).order(category.asc)
        let categoryResult = try! db?.prepare(categoryQuery!)
        for c in categoryResult! {
            let name = c[category]
            let sum = try! db?.scalar((table?.select(cost.total).filter(category == Expression<String>(name)).filter(date >= fromDate))!)
            data.append(ExpenseCategory(name: name, sum: sum!))
        }
        setChartData()
    }
    
    // MARK: LineChartView
    
    func setChartData() {
        
        var dates: [String] = []
        var expenseTotal: [Double] = []

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var currDate: Date! = df.date(from: fromDate)
        let today = Date()
        let cal = Calendar.current
        
        var dateFrequencyComponent = DateComponents()
        switch dateFrames.first!.0 {
        case NSLocalizedString("30 Days", comment: "30 Days"):
            dateFrequencyComponent.day = 1
        default:
            dateFrequencyComponent.day = 7
        }
        
        while currDate <= today {
            dates.append(df.string(from: currDate))
            expenseTotal.append(0)
            currDate = cal.date(byAdding: dateFrequencyComponent, to: currDate)
        }
        
        let filteredTable = table?.order(date.asc, id.asc).filter(date >= fromDate)
        let items = try! db?.prepare(filteredTable!)
        
        var dateIndex = 0
        for item in items! {
            while dateIndex < dates.count-1 && df.date(from: dates[dateIndex+1])! <= df.date(from: item[date])! {
                dateIndex += 1
            }
            expenseTotal[dateIndex] += item[cost]
        }
        
        lcf.data = dates
        
        var chartDataEntries = [ChartDataEntry]()
        // TODO: x axis dates
        for i in 0 ..< dates.count {
            let x = XAxis()
            x.valueFormatter = lcf
            chartDataEntries.append(ChartDataEntry(x: Double(i), y: expenseTotal[i]))
        }
        
        let chartDataSet = LineChartDataSet(values: chartDataEntries, label: "Daily Expenses")
        chartDataSet.colors = [UIColor(red: 224/255, green: 39/255, blue: 68/255, alpha: 1)]
        chartDataSet.drawCirclesEnabled = false
        chartDataSet.drawValuesEnabled = false
        
        var chartDataSets = [LineChartDataSet]()
        chartDataSets.append(chartDataSet)

        // Hardcoded
        var target: Double
        switch dateFrames.first!.0 {
        case NSLocalizedString("30 Days", comment: "30 Days"):
            target = 15.78
        default:
            target = 110.76
        }
        let ll = ChartLimitLine(limit: target, label: "Target")
        ll.drawLabelEnabled = false
        chartView.rightAxis.removeAllLimitLines()
        chartView.rightAxis.addLimitLine(ll)
        
        chartView.data = LineChartData(dataSets: chartDataSets)
        chartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0, easingOption: .easeInElastic)
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
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
