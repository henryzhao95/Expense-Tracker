import SwiftUI

struct CategoryPickerView: View {
    var categories: [String]
    @Binding var selectedCategory: String
    
    let cornerRadius: CGFloat = 8
    
    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())]) {
                ForEach((1...categories.count), id: \.self) { index in
                    Button(action: {
                        selectedCategory = categories[index - 1]
                    }, label: {
                        Text(categories[index - 1])
                            // .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                            .padding(.horizontal, 6)
                    })
                    .frame(width: 110, alignment: .center)
                    .frame(height: 50, alignment: .center)
                    .background(categories[index - 1] == selectedCategory ? Color(UIColor.systemGray3) : Color(UIColor.systemGray5))
                    .cornerRadius(cornerRadius)
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
                .padding(.horizontal, 6)
            }
            .padding(.vertical, 6)
            .frame(height: 150)
        }
    }
}

struct CategoryPickerView_Previews: PreviewProvider {
    @State static var selectedCategory = "Food"
    static var categories = ["Misc", "Food", "Recreation", "Travel", "Health", "Giving", "Transport"]
    
    static var previews: some View {
        CategoryPickerView(categories: categories, selectedCategory: $selectedCategory
        )
    }
}
