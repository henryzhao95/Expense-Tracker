import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var viewModel: ExpensesViewModel
    
    /*
     Time frame for the Overview
     Used like a rotating list, where [0] is current
     (Month, 2016-02-01)
     */
    @State var dateFrames = [(String, String)]()
    @State var selectedDateFrameIndex: Int? = nil
    @State var selectedCategory: String? = nil
    
    // "2016-02-01", used by reloadData() to restrict SQLite query
    @State var fromDate: String!
        
    var body: some View {
        return VStack {
            List {
                ForEach(viewModel.expensesByCategory, id: \.self.name) { expenseCategory in
                    CategoryCellView(expenseCategory: expenseCategory)
                        .contentShape(Rectangle()) // makes whole row tappable
                        .onTapGesture {
                            if (selectedCategory == expenseCategory.name) {
                                selectedCategory = nil
                            } else {
                                selectedCategory = expenseCategory.name
                            }
                            viewModel.loadExpensesByTime(fromDate: fromDate, categoryFilter: selectedCategory)
                        }
                        .listRowBackground(expenseCategory.name == selectedCategory ? Color(.systemFill) : Color(.systemBackground))
                }
            }
            .listStyle(PlainListStyle())
            ExpenseChartView()
        }
        .navigationTitle("Overview")
        .navigationBarItems(trailing: Button(dateFrames.first?.0 ?? "Loading...", action: toggleDateFrame))
        .onAppear {
            reloadDateFrames()
            viewModel.loadExpensesByCategory(fromDate: fromDate)
            viewModel.loadExpensesByTime(fromDate: fromDate, categoryFilter: selectedCategory)
        }
    }
    
    func toggleDateFrame() {
        dateFrames.append(dateFrames.removeFirst())
        fromDate = dateFrames.first?.1
        
        viewModel.loadExpensesByCategory(fromDate: fromDate)
        viewModel.loadExpensesByTime(fromDate: fromDate, categoryFilter: selectedCategory)
    }
    
    func reloadDateFrames() {
        dateFrames.removeAll()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd" // for SQLite call
        
        let date = Date()
        let cal = Calendar.current
        let components = (cal as NSCalendar).components([.day, .month, .year], from: date)
        
        fromDate = df.string(from: date.addingTimeInterval(-29*24*60*60)) // + today
        dateFrames.append(("28 " + NSLocalizedString("Days", comment: "Days"), fromDate))
        
        let tempDate = df.string(from: date.addingTimeInterval(-90*24*60*60)) // + today
        dateFrames.append(("91 " + NSLocalizedString("Days", comment: "Days"), tempDate))
        
        var fyStart = components.year!
        if components.month! <= 6 { // 2016-02 is in 2015-16
            fyStart = fyStart - 1 // financial year
        }
        let fyString = String(describing: fyStart) + "-07-01"
        let fyEnd = fyStart % 100 + 1
        let fyTitle = String(describing: fyStart) + "-" + String(fyEnd) + " " + NSLocalizedString("FY", comment: "Financial Year")
        dateFrames.append((fyTitle, fyString))
    }
}

struct OverviewView_Previews: PreviewProvider {
    static var previews: some View {
        OverviewView()
            .environmentObject(ExpensesViewModel(data: testData))
    }
}
