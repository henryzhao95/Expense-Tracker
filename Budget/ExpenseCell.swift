//
//  ExpenseCell.swift
//  Budget
//
//  Created by Henry Zhao on 15/02/2016.
//  Copyright © 2016 Henry Zhao. All rights reserved.
//

import UIKit

class ExpenseCell: UITableViewCell {
    
    var id: Int64!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var costLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setCost(_ c: Double) {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        costLabel.text = nf.string(from: NSNumber(value: c as Double))
    }
}
