//
//  DatabaseManager.swift
//  Budget
//
//  Created by Henry Zhao on 29/02/2016.
//  Copyright © 2016 Henry Zhao. All rights reserved.
//

import Foundation
import SQLite

let id = SQLite.Expression<Int64>("id")
let date = SQLite.Expression<String>("date")
let cost = SQLite.Expression<Double>("cost")
let category = SQLite.Expression<String>("category")
let desc = SQLite.Expression<String?>("description")
let annualTarget = SQLite.Expression<Double?>("annualTarget")

class DatabaseManager {
    
    static let sharedInstance = DatabaseManager()
    let ExpensesTableName = "expenses"
    let TargetsTableName = "targets"
    
    var db: Connection!
    var expensesTable: Table!
    var targetsTable: Table!

    init() {
        db = try! Connection(getURL().path!)
        print(getURL().path!)
        
        expensesTable = Table(ExpensesTableName)
        
        do {
            _ = try db.scalar(expensesTable.exists)
        } catch {
            let newExpensesTable = Table(ExpensesTableName)
            
            try! db.run(newExpensesTable.create { t in
                t.column(id, primaryKey: true)
                t.column(date)
                t.column(cost)
                t.column(category)
                t.column(desc)
                })
            
            try! db.run(newExpensesTable.createIndex(date, id))
        }
        
        targetsTable = Table(TargetsTableName)
        
        do {
            _ = try db.scalar(targetsTable.exists)
        } catch {
            let newTargetsTable = Table(TargetsTableName)
            
            try! db.run(newTargetsTable.create { t in
                t.column(category, primaryKey: true)
                t.column(annualTarget)
                })
        }
    }
    
    func getURL() -> NSURL {
        return NSURL(string: "expenses.sqlite3", relativeTo: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])!
    }
}
