//
//  ExpensesViewController.swift
//  Budget
//
//  Created by Henry Zhao on 4/01/2016.
//  Copyright © 2016 Henry Zhao. All rights reserved.
//

import UIKit
import SQLite
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class HistoryViewController: UITableViewController, ExpenseViewControllerDelegate {
    
    // MARK: Properties
    
    struct Section {
        var date: String
        var expenses: [Expense]!
    }
    
    let db = DatabaseManager.sharedInstance.db
    let table = DatabaseManager.sharedInstance.table
    
    var data = [Section]()
    var dbOffset = 0
    
    var selectedPath: IndexPath!
    
    var dbLoadedBool = false
    var dbLoaded: Bool {
        return dbLoadedBool
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        loadData()
        dbLoadedBool = true
        
        // Table
        tableView.estimatedRowHeight = 60 // random height
        tableView.estimatedSectionHeaderHeight = 22
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: NSNotification.Name(rawValue: "UIContentSizeCategoryDidChangeNotification"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if selectedPath != nil {
            tableView.deselectRow(at: selectedPath, animated: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func contentSizeCategoryDidChange() {
        tableView.reloadData()
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if tableView.contentOffset.y >= tableView.contentSize.height - tableView.frame.size.height {
            loadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destinationViewController = segue.destination as! ExpenseViewController

        if sender is ExpenseCell {
            self.selectedPath = tableView.indexPath(for: sender as! ExpenseCell)
            destinationViewController.expense = self.data[selectedPath.section].expenses[selectedPath.row]
        } else {
            selectedPath = nil
        }
        
        // Delegate set in ExpenseViewController
        destinationViewController.edit = true
    }
    
    // MARK: UITableView
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Called after prepareForSegue() so useless
    }
    
    func deleteFromDataAndTableIndexPath(_ indexPath: IndexPath, withRowAnimation rowAnimation: UITableViewRowAnimation) {
        // Delete from [data]
        data[indexPath.section].expenses.remove(at: indexPath.row)
        // Delete table section if applicable
        if data[indexPath.section].expenses.isEmpty {
            data.remove(at: indexPath.section)
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: rowAnimation)
        } else {
            // Delete table row
            tableView.deleteRows(at: [indexPath], with: rowAnimation)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return data.count
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            let cell = tableView.cellForRow(at: indexPath) as! ExpenseCell
            try! db?.run((table?.filter(id == cell.id).delete())!)
            deleteFromDataAndTableIndexPath(indexPath, withRowAnimation: .automatic)
            dbOffset -= 1
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data[section].expenses.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cell = tableView.dequeueReusableCell(withIdentifier: "expenseCell", for: indexPath) as! ExpenseCell
        let e = data[indexPath.section].expenses[indexPath.row]
        cell.id = e.id
        cell.categoryLabel.text = e.category
        cell.setCost(e.cost)
        cell.descLabel.text = e.desc?.count > 0 ? e.desc : nil
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let temp = df.date(from: data[section].date)
        df.dateStyle = .full
        cell!.textLabel!.text = df.string(from: temp!)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    // MARK: Data

    func loadData() {
        var newSections = 0
        var newRows = [IndexPath]()
        
        let filterdTable = table?.order(date.desc, id.desc).limit(50, offset: dbOffset)
        let items = try! db?.prepare(filterdTable!)
        for item in items! {
            let e = Expense(id: item[id], date: item[date], cost: item[cost], category: item[category], description: item[desc])
            
            var sectionNumber = data.count
            let currDate = e.date
            for s in data.reversed() {
                if currDate >= s.date {
                    sectionNumber -= 1
                } else {
                    break
                }
            }
            
            if data.isEmpty || sectionNumber == data.count || currDate != data[sectionNumber].date {
                data.insert(Section(date: currDate, expenses: [Expense]()), at: sectionNumber)
                newSections += 1
            }
            
            // Insert at top by default, ordered by id
            var rowNumber = 0
            var duplicate = false
            for i in data[sectionNumber].expenses {
                if e.id < i.id {
                    rowNumber += 1
                } else if e.id == i.id {
                    duplicate = true
                } else {
                    break
                }
            }
            
            if !duplicate {
                data[sectionNumber].expenses.insert(e, at: rowNumber)
                newRows.append(IndexPath(row: rowNumber, section: sectionNumber))
            }
        }

        if newRows.count > 0 {
            tableView.beginUpdates()
            tableView.insertSections(IndexSet(integersIn: NSMakeRange(data.count - newSections, newSections).toRange() ?? 0..<0), with: .none)
            tableView.insertRows(at: newRows, with: .none)
            dbOffset += newRows.count
            tableView.endUpdates()
        }
    }
    
    func updateExpense(_ e: Expense) {
        if e.date == data[selectedPath.section].date {
            tableView.reloadRows(at: [IndexPath](arrayLiteral: selectedPath), with: .automatic)
        } else {
            data[selectedPath.section].expenses.remove(at: selectedPath.row)
            tableView.deleteRows(at: [IndexPath](arrayLiteral: selectedPath), with: .automatic)
            if data[selectedPath.section].expenses.count == 0 {
                data.remove(at: selectedPath.section)
                tableView.deleteSections(IndexSet(integer: selectedPath.section), with: .automatic)
            }
            insertIntoDataAndTableExpense(e, withRowAnimation: .automatic)
        }
        // Allows duplicates because loadData() checks
        if dbOffset > 0 {
            dbOffset -= 1
        }
    }
    
    func addExpense(_ e: Expense) {
        insertIntoDataAndTableExpense(e, withRowAnimation: .automatic)
        // Allows duplicates because loadData() checks
        if dbOffset > 0 {
            dbOffset -= 1
        }
    }
    
    func insertIntoDataAndTableExpense(_ e: Expense, withRowAnimation rowAnimation: UITableViewRowAnimation) -> IndexPath {
        var sectionNumber = 0
        let currDate = e.date
        for s in data {
            if currDate >= s.date {
                break
            } else {
                sectionNumber += 1
            }
        }
        
        // Insert at front, end or no section created yet
        // Order of these checks matter
        if data.isEmpty || sectionNumber == data.count || currDate != data[sectionNumber].date {
            data.insert(Section(date: currDate, expenses: [Expense]()), at: sectionNumber)
            tableView.insertSections(IndexSet(integer: sectionNumber), with: rowAnimation)
        }
        
        // Insert at top by default, ordered by id
        var rowNumber = 0
        for i in data[sectionNumber].expenses {
            if e.id < i.id {
                rowNumber += 1
            }
        }
        data[sectionNumber].expenses.insert(e, at: rowNumber)
        
        let indexPath = IndexPath(row: rowNumber, section: sectionNumber)
        tableView.insertRows(at: [indexPath], with: rowAnimation)
        return indexPath
    }
}
