//
//  DatabaseManager.swift
//  Budget
//
//  Created by Henry Zhao on 29/02/2016.
//  Copyright © 2016 Henry Zhao. All rights reserved.
//

import Foundation
import SQLite

let id = Expression<Int64>("id")
let date = Expression<String>("date")
let cost = Expression<Double>("cost")
let category = Expression<String>("category")
let desc = Expression<String?>("description")

class DatabaseManager {
    
    static let sharedInstance = DatabaseManager()
    
    var db: Connection!
    var table: Table!
    
    let id = Expression<Int64>("id")
    let date = Expression<String>("date")
    let cost = Expression<Double>("cost")
    let category = Expression<String>("category")
    let desc = Expression<String?>("description")
    
    init() {
        db = try! Connection(getURL().path!)
        print(getURL().path!)
        if dbEmpty() {
            newTable("expenses")
        }
        table = Table("expenses")
    }
    
    func getURL() -> NSURL {
        return NSURL(string: "expenses.sqlite3", relativeTo: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])!
    }
    
    func dbEmpty() -> Bool {
        let sqlite_master = Table("sqlite_master")
        let count = try! db.scalar(sqlite_master.count)
        return count == 0
    }
    
    func newTable(_ name: String) {
        let new = Table(name)
        
        try! db.run(new.create { t in
            t.column(id, primaryKey: true)
            t.column(date)
            t.column(cost)
            t.column(category)
            t.column(desc)
            })
        
        try! db.run(new.createIndex(date, id))
    }
}
