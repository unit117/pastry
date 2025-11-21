#if canImport(SwiftUI)
import SwiftUI

struct RecipesView: View {
    let recipes: [Recipe]
    @State private var selection: Recipe?

    var body: some View {
        NavigationView {
            List(recipes, selection: $selection) { recipe in
                Text(recipe.names.value())
            }
            .listStyle(SidebarListStyle())

            if let recipe = selection ?? recipes.first {
                RecipeDetailView(recipe: recipe)
            } else {
                Text("Select a recipe")
            }
        }
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.names.value())
                    .font(.title)
                if let fr = recipe.names.values["fr"] {
                    Text(fr).foregroundColor(.secondary)
                }
                if let amount = recipe.yieldAmount, let unit = recipe.yieldUnit {
                    Text("Yield: \(amount) \(unit)")
                        .font(.headline)
                }
                Divider()
                Text("Ingredients")
                    .font(.headline)
                ForEach(recipe.ingredients) { ingredient in
                    HStack {
                        Text(ingredient.catalogueID)
                        Spacer()
                        if let q = ingredient.quantity {
                            Text(String(format: "%.2f", q))
                        }
                        if let unit = ingredient.unit { Text(unit) }
                    }
                }
                Divider()
                Text("Instructions")
                    .font(.headline)
                ForEach(recipe.instructions["en"] ?? [], id: \.self) { step in
                    Text("• \(step)")
                }
            }
            .padding()
        }
    }
}
#endif
