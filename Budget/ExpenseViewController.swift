//
//  ExpenseDetailViewController.swift
//  Budget
//
//  Created by Henry Zhao on 28/02/2016.
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


class ExpenseViewController: UIViewController, UITextFieldDelegate {
    
    let greyColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1)
    let redColor = UIColor(red: 224/255, green: 39/255, blue: 68/255, alpha: 1)
    
    // Determines whether to create or update, how to handle View Controllers
    var edit = false
    // First back press clears costLabel
    var firstEdit = true
    var delegate: ExpenseViewControllerDelegate!
    
    @IBOutlet weak var categoryView: UICollectionView!
    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var descTextField: UITextField!
    @IBOutlet weak var currencyLabel: UILabel!
    @IBOutlet weak var costLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var dotButton: UIButton!

    var categorySelected: String!
    var lastSelectedCategory: IndexPath!
    var datePicker = UIDatePicker()
    
    let db = DatabaseManager.sharedInstance.db
    let table = DatabaseManager.sharedInstance.table
    var expense: Expense!
    
    var categories = [String]()
    
    let df = DateFormatter()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if edit {
            categoryView.reloadData() // Force Touch preview has different size
        } else {
            /* Not working
            print(Date())
            datePicker.date = Date() // in case date has changed since cached
            datePicker.reloadInputViews()
            print(datePicker.date)
             */
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        let currencyString = nf.string(from: NSNumber(value: 0 as Double))!
        let currencySymbol = currencyString[currencyString.startIndex]
        currencyLabel.text = String(currencySymbol)
        
        descTextField.delegate = self
        
        dateTextField.inputView = datePicker
        setupDatePicker()
        
        let categoryQuery = table?.select(distinct: category).order(date.desc)
        let categoryResult = try! db?.prepare(categoryQuery!)
        for c in categoryResult! {
            categories.append(c[category])
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let tabBarVC = appDelegate.window!.rootViewController as! UITabBarController
        delegate = tabBarVC.childViewControllers[2].childViewControllers[0] as! HistoryViewController
        
        if edit == false {
            newExpense()
        } else {
            populateViewWithExpense()
        }
        
        if costLabel.text?.contains(".") == true {
            dotButton.isEnabled = false
        } else {
            dotButton.isEnabled = true
        }
    }
    
    func newExpense() {
        edit = false
        var category: String
        if categories.first != nil {
            category = categories.first!
        } else {
            category = NSLocalizedString("Other", comment: "Miscellaneous")
        }
        df.dateFormat = "yyyy-MM-dd"
        expense = Expense(date: df.string(from: Date()), category: category)
        saveButton.isEnabled = false
        dotButton.isEnabled = true
        categoryView.reloadData() // Categories rearranged after saving
        populateViewWithExpense()
    }
    
    func populateViewWithExpense() {
        categorySelected = expense.category
        // Date
        dateTextField.text = expense.longDate()
        df.dateFormat = "yyyy-MM-dd"
        datePicker.date = df.date(from: expense.date)!
        
        descTextField.text = expense.desc
        if edit {
            firstEdit = true
            costLabel.text = String(expense.cost)
            saveButton.setTitle(NSLocalizedString("Update", comment: "Update"), for: UIControlState())
        } else {
            costLabel.text = "" // Don't show 0.00
        }
    }
    
    func colourCell(_ cell: CategoryCell, selected: Bool) {
        if selected {
            cell.label.textColor = redColor
            cell.backgroundColor = UIColor.white
            cell.layer.borderColor = greyColor.cgColor
            cell.layer.borderWidth = 5
        } else {
            cell.label.textColor = UIColor.black
            cell.backgroundColor = greyColor
            cell.layer.borderWidth = 0
        }
    }
    
    func setupDatePicker() {
        datePicker.datePickerMode = .date
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 44))
        let toolbarPaddingButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let toolbarDoneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(toolbarDone))
        toolbar.items = [toolbarPaddingButton, toolbarDoneButton]
        dateTextField.inputAccessoryView = toolbar
    }
    
    func toolbarDone(_ sender: UITextField) {
        dateTextField.resignFirstResponder()
        df.dateStyle = .long
        dateTextField.text = df.string(from: datePicker.date)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    // MARK: Buttons
    
    @IBAction func buttonNumber(_ sender: UIButton) {
        firstEdit = false
        costLabel.text = costLabel.text! + sender.titleLabel!.text!
        saveButton.isEnabled = true
    }
    
    @IBAction func buttonPeriod(_ sender: UIButton) {
        costLabel.text = costLabel.text! + "."
        dotButton.isEnabled = false
    }
    
    @IBAction func buttonSave(_ sender: UIButton) {
        if categories.first != nil {
            let reorderIndex = categories.index(of: categorySelected)
            categories.insert(categories.remove(at: reorderIndex!), at: 0)
        } else {
            // Default category when there are none
            categories.append(categorySelected)
        }
        
        expense.category = categorySelected
        expense.date = shortDate(dateTextField.text!)
        expense.desc = descTextField.text
        expense.cost = NSString(string: costLabel.text!).doubleValue
        
        if expense.id > 0 {
            dbUpdateExpense(expense)
            delegate.updateExpense(expense)
            navigationController!.popViewController(animated: true)
        } else {
            expense.id = dbNewExpense(expense)
            if delegate.dbLoaded {
                delegate.addExpense(expense)
            }
            tabBarController!.selectedIndex = 2
            (tabBarController!.selectedViewController! as! UINavigationController).popToRootViewController(animated: true)
        }
        
        newExpense() // Reset Expense view
    }
    
    @IBAction func buttonBack(_ sender: UIButton) {
        // To do: speed up delete when holding down button
        if costLabel.text?.count > 0 {
            costLabel.text = String(costLabel.text!.characters.dropLast())
            if costLabel.text?.count < 1 || firstEdit {
                saveButton.isEnabled = false
            }
            if firstEdit {
                costLabel.text = ""
            }
            if costLabel.text?.contains(".") == true {
                dotButton.isEnabled = false
            } else {
                dotButton.isEnabled = true
            }
        }
    }
    
    // MARK: Data
    
    func shortDate(_ longDate: String) -> String {
        df.dateStyle = .long
        let tempDate = df.date(from: longDate)!
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: tempDate)
    }
    
    func dbNewExpense(_ e: Expense) -> Int64 {
        // Row ID automatically chosen
        try! db?.run((table?.insert(cost <- e.cost, category <- e.category, desc <- e.desc, date <- e.date))!)
        // Row ID to pass back
        return try! db!.prepare("SELECT LAST_INSERT_ROWID()").next()![0]! as! Int64
    }
    
    func dbUpdateExpense(_ e: Expense) {
        let row = table?.filter(id == e.id)
        try! db?.run((row?.update(cost <- e.cost, category <- e.category, desc <- e.desc, date <- e.date))!)
    }
}

extension ExpenseViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "categoryCell", for: indexPath) as! CategoryCell
        
        // Not the "New Category" button
        if indexPath.row != categories.count {
            cell.label.text = categories[indexPath.row]
            if cell.label.text == categorySelected {
                colourCell(cell, selected: true)
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: UICollectionViewScrollPosition()) // First launch
            } else {
                colourCell(cell, selected: false)
            }
        } else {
            cell.label.text = NSLocalizedString("New Category", comment: "New Category")
            cell.label.textColor = redColor
            cell.backgroundColor = greyColor
            cell.layer.borderColor = redColor.cgColor
            cell.layer.borderWidth = 5
        }

        return cell
    }
}

extension ExpenseViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! CategoryCell
        
        if indexPath.row != categories.count {
            categorySelected = cell.label.text
            UIView.animate(withDuration: 0.2, animations: {
                self.colourCell(cell, selected: true)
            })
        } else {
            if !unlimitedCategories {
                /*
                let alert = UIAlertController(title: NSLocalizedString("Reached Categories Limit", comment: "Reached Categories Limit"), message: nil, preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .Cancel, handler: { cancelAction -> Void in
                    // alert.textFields![0].resignFirstResponder()
                    // self.categorySelected = self.categories[self.lastSelectedCategory.row]
                    if let cell = collectionView.cellForItemAtIndexPath(self.lastSelectedCategory) {
                        UIView.animateWithDuration(0.2, animations: {
                            self.colourCell(cell as! CategoryCell, selected: true)
                        })
                        collectionView.selectItemAtIndexPath(self.lastSelectedCategory, animated: false, scrollPosition: .None)
                    }
                }))
                let save = UIAlertAction(title: NSLocalizedString("Add", comment: "Add"), style: .Default, handler: { saveAction -> Void in
                    alert.textFields![0].resignFirstResponder()
                    self.categorySelected = alert.textFields![0].text!
                    self.categories.append(self.categorySelected)
                    let newPath = NSIndexPath(forItem: self.categories.count-1, inSection: 0)
                    collectionView.insertItemsAtIndexPaths([newPath])
                })
                save.enabled = false
                alert.addAction(save)
                alert.addTextFieldWithConfigurationHandler { alertField -> Void in
                    alertField.placeholder = NSLocalizedString("Category Name", comment: "Category Name")
                    alertField.addTarget(self, action: #selector(self.categoryAlertTextChanged), forControlEvents: .EditingChanged)
                }
                presentViewController(alert, animated: true, completion: nil)
                 */
            }
            showNewCategoryAlert(collectionView)
        }
    }
    
    func showNewCategoryAlert(_ collectionView: UICollectionView) {
        let alert = UIAlertController(title: NSLocalizedString("New Category", comment: "New Category"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { cancelAction -> Void in
            alert.textFields![0].resignFirstResponder()
            self.categorySelected = self.categories[self.lastSelectedCategory.row]
            if let cell = collectionView.cellForItem(at: self.lastSelectedCategory) {
                UIView.animate(withDuration: 0.2, animations: {
                    self.colourCell(cell as! CategoryCell, selected: true)
                })
                collectionView.selectItem(at: self.lastSelectedCategory, animated: false, scrollPosition: UICollectionViewScrollPosition())
            }
        }))
        let save = UIAlertAction(title: NSLocalizedString("Add", comment: "Add"), style: .default, handler: { saveAction -> Void in
            alert.textFields![0].resignFirstResponder()
            self.categorySelected = alert.textFields![0].text!
            self.categories.append(self.categorySelected)
            let newPath = IndexPath(item: self.categories.count-1, section: 0)
            collectionView.insertItems(at: [newPath])
        })
        save.isEnabled = false
        alert.addAction(save)
        alert.addTextField { alertField -> Void in
            alertField.placeholder = NSLocalizedString("Category Name", comment: "Category Name")
            alertField.addTarget(self, action: #selector(self.categoryAlertTextChanged), for: .editingChanged)
        }
        present(alert, animated: true, completion: nil)
    }
    
    func categoryAlertTextChanged(_ sender: AnyObject) {
        let field = sender as! UITextField
        var responder = sender
        while !(responder is UIAlertController) {
            responder = responder.next!!
        }
        let alert = responder as! UIAlertController
        if field.text?.count > 0 {
            alert.actions[1].isEnabled = true
        } else {
            alert.actions[1].isEnabled = false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        self.lastSelectedCategory = indexPath
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.2, animations: {
                self.colourCell(cell as! CategoryCell, selected: false)
            })
        }
    }
}

extension ExpenseViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let superviewHeight = collectionView.frame.height
        let superviewWidth = collectionView.frame.width/2.4
        var height: CGFloat
        if superviewHeight < 100 {
            height = superviewHeight
        } else {
            // 2 columns
            height = superviewHeight/2-10
        }
        return (CGSize(width: superviewWidth, height: height))
    }
        
}

protocol ExpenseViewControllerDelegate {
    func updateExpense(_ e: Expense)
    func addExpense(_ e: Expense)
    var dbLoaded: Bool { get }
}
