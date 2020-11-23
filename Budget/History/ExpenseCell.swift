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
        costLabel.text = Formatter.currencyFormatter.string(from: NSNumber(value: c as Double))
    }
}
