//
//  OverviewViewController.swift
//  Budget
//
//  Created by Henry Zhao on 25/02/2016.
//  Copyright © 2016 Henry Zhao. All rights reserved.
//

import UIKit
import SQLite

class OverviewViewController: UITableViewController {
    
    struct ExpenseCategory {
        var name: String
        var sum: Double
    }
    
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
        
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableViewAutomaticDimension
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
    }
    
    // MARK: UITableView
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count + 1 // + 1 for footer total
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
