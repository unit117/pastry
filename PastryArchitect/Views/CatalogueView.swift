import SwiftUI

struct CatalogueView: View {
    let items: [CatalogueItem]
    @Binding var searchText: String
    var onRefresh: () -> Void

    var body: some View {
        VStack {
            HStack {
                TextField("Search by name or category", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()
            Table(items) {
                TableColumn("ID", value: \.id)
                TableColumn("Name") { item in
                    Text(item.names.value())
                }
                TableColumn("Category", value: \.category)
                TableColumn("Default Unit", value: \.defaultUnit)
            }
        }
    }
}
