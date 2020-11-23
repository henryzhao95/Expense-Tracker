//
//  Formatter.swift
//  Expenses
//
//  Created by Henry Zhao on 27/6/20.
//  Copyright © 2020 Henry Zhao. All rights reserved.
//

import Foundation

class Formatter {
    static var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone.current
        f.timeStyle = .none
        return f
    }()
    static var currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.isLenient = true
        f.numberStyle = .currency
        return f
    }()
    static var isoDateFormat = "yyyy-MM-dd"
    
    // from Date to 2020-07-01
    static func isoDate(_ date: Date) -> String {
        dateFormatter.dateFormat = isoDateFormat
        return dateFormatter.string(from: date)
    }
    
    // from 2020-07-01 to Date
    static func dateFromIso(_ date: String) -> Date {
        dateFormatter.dateFormat = isoDateFormat
        return dateFormatter.date(from: date)!
    }
    
    // from 2020-07-01 to Wednesday, 1 July 2020
    static func formatDate(_ date: String) -> String {
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = isoDateFormat
        let temp = dateFormatter.date(from: date)
        dateFormatter.dateFormat = nil
        dateFormatter.dateStyle = .full
        return dateFormatter.string(from: temp!)
    }

    // from 10 to 10.00
    static func formatCost(_ c: Double) -> String {
        return currencyFormatter.string(from: NSNumber(value: c as Double)) ?? "?"
     }
}
