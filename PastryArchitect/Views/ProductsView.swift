import SwiftUI

struct ProductsView: View {
    let products: [Product]
    @State private var selection: Product?

    var body: some View {
        NavigationView {
            List(products, selection: $selection) { product in
                Text(product.names.value())
            }
            if let product = selection ?? products.first {
                ProductDetailView(product: product)
            } else {
                Text("Select a product")
            }
        }
    }
}

struct ProductDetailView: View {
    let product: Product
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(product.names.value())
                    .font(.title)
                if let description = product.description?["en"] {
                    Text(description)
                        .foregroundColor(.secondary)
                }
                Divider()
                Text("Components")
                    .font(.headline)
                ForEach(product.components) { component in
                    HStack {
                        Text(component.referenceID)
                        Spacer()
                        if let q = component.quantity { Text(String(format: "%.2f", q)) }
                        if let unit = component.unit { Text(unit) }
                    }
                }
                if let assembly = product.assemblyInstructions?["en"] {
                    Divider()
                    Text("Assembly")
                        .font(.headline)
                    ForEach(assembly, id: \.self) { step in
                        Text("• \(step)")
                    }
                }
            }
            .padding()
        }
    }
}
