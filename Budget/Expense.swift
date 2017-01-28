//
//  Expense.swift
//  Budget
//
//  Created by Henry Zhao on 18/02/2016.
//  Copyright © 2016 Henry Zhao. All rights reserved.
//

import UIKit

class Expense: NSObject {
    
    var id: Int64
    var date: String
    var cost: Double
    var category: String
    var desc: String?
        
    init(id: Int64 = 0, date: String, cost: Double = 0, category: String, description: String? = nil) {
        self.id = id
        self.date = date
        self.cost = cost
        self.category = category
        self.desc = description
    }
    
    func longDate() -> String {
        let df = DateFormatter()
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        let temp = df.date(from: date)
        df.dateFormat = nil
        df.dateStyle = .long
        df.timeStyle = .none
        return df.string(from: temp!)
    }
}
