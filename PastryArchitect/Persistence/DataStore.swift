import Foundation
#if canImport(SQLite3)

final class DataStore {
    private let database: SQLiteDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(databasePath: String = DataStore.defaultPath) throws {
        database = try SQLiteDatabase(path: databasePath)
    }

    static var defaultDirectory: URL {
#if os(macOS)
        if let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return supportDir.appendingPathComponent("PastryArchitect", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("PastryArchitect", isDirectory: true)
#elseif os(iOS)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents.appendingPathComponent("PastryArchitect", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("PastryArchitect", isDirectory: true)
#else
        return FileManager.default
            .temporaryDirectory
            .appendingPathComponent("PastryArchitect", isDirectory: true)
#endif
    }

    static var defaultPath: String {
        defaultDirectory.appendingPathComponent("pastry.sqlite").path
    }

    func save(payload: ParsedPayload) throws {
        try database.execute(sql: "BEGIN TRANSACTION")
        defer { try? database.execute(sql: "COMMIT") }
        try insertCatalogue(payload.catalogue)
        try insertRecipes(payload.recipes)
        try insertProducts(payload.products)
    }

    private func insertCatalogue(_ items: [CatalogueItem]) throws {
        let sql = "INSERT OR REPLACE INTO catalogue (id, names_json, category, defaultUnit) VALUES (?, ?, ?, ?)"
        for item in items {
            let namesJSON = String(data: try encoder.encode(item.names), encoding: .utf8) ?? "{}"
            try database.execute(sql: sql, parameters: [item.id, namesJSON, item.category, item.defaultUnit])
        }
    }

    private func insertRecipes(_ items: [Recipe]) throws {
        let sql = "INSERT OR REPLACE INTO recipes (id, names_json, yieldAmount, yieldUnit, instructions_json, ingredients_json) VALUES (?, ?, ?, ?, ?, ?)"
        for recipe in items {
            let namesJSON = String(data: try encoder.encode(recipe.names), encoding: .utf8) ?? "{}"
            let instructionsJSON = String(data: try JSONSerialization.data(withJSONObject: recipe.instructions), encoding: .utf8) ?? "{}"
            let ingredientsJSON = String(data: try encoder.encode(recipe.ingredients), encoding: .utf8) ?? "[]"
            try database.execute(sql: sql, parameters: [recipe.id, namesJSON, recipe.yieldAmount ?? NSNull(), recipe.yieldUnit ?? NSNull(), instructionsJSON, ingredientsJSON])
        }
    }

    private func insertProducts(_ items: [Product]) throws {
        let sql = "INSERT OR REPLACE INTO products (id, names_json, description_json, components_json, assembly_instructions_json) VALUES (?, ?, ?, ?, ?)"
        for product in items {
            let namesJSON = String(data: try encoder.encode(product.names), encoding: .utf8) ?? "{}"
            let descriptionJSON = product.description.flatMap { String(data: try! JSONSerialization.data(withJSONObject: $0), encoding: .utf8) }
            let componentsJSON = String(data: try encoder.encode(product.components), encoding: .utf8) ?? "[]"
            let assemblyJSON = product.assemblyInstructions.flatMap { String(data: try! JSONSerialization.data(withJSONObject: $0), encoding: .utf8) }
            try database.execute(sql: sql, parameters: [product.id, namesJSON, descriptionJSON ?? NSNull(), componentsJSON, assemblyJSON ?? NSNull()])
        }
    }

    func fetchCatalogue(search: String? = nil) throws -> [CatalogueItem] {
        var items: [CatalogueItem] = []
        var sql = "SELECT * FROM catalogue"
        var parameters: [Any] = []
        if let search, !search.isEmpty {
            sql += " WHERE names_json LIKE ? OR category LIKE ?"
            let token = "%\(search)%"
            parameters = [token, token]
        }
        try database.query(sql: sql, parameters: parameters) { row in
            if let id = row["id"] as? String,
               let namesText = row["names_json"] as? String,
               let category = row["category"] as? String,
               let defaultUnit = row["defaultUnit"] as? String,
               let namesData = namesText.data(using: .utf8),
               let names = try? decoder.decode(LocalizedText.self, from: namesData) {
                items.append(CatalogueItem(id: id, names: names, category: category, defaultUnit: defaultUnit))
            }
        }
        return items
    }

    func fetchRecipes() throws -> [Recipe] {
        var items: [Recipe] = []
        try database.query(sql: "SELECT * FROM recipes") { row in
            guard let id = row["id"] as? String,
                  let namesText = row["names_json"] as? String,
                  let instructionsText = row["instructions_json"] as? String,
                  let ingredientsText = row["ingredients_json"] as? String,
                  let namesData = namesText.data(using: .utf8),
                  let names = try? decoder.decode(LocalizedText.self, from: namesData),
                  let instructionsData = instructionsText.data(using: .utf8),
                  let instructions = try? JSONSerialization.jsonObject(with: instructionsData) as? [String: [String]],
                  let ingredientsData = ingredientsText.data(using: .utf8),
                  let ingredients = try? decoder.decode([RecipeIngredient].self, from: ingredientsData) else {
                return
            }
            let yieldAmount = row["yieldAmount"] as? Double
            let yieldUnit = row["yieldUnit"] as? String
            items.append(Recipe(id: id, names: names, yieldAmount: yieldAmount, yieldUnit: yieldUnit, instructions: instructions, ingredients: ingredients))
        }
        return items
    }

    func fetchProducts() throws -> [Product] {
        var items: [Product] = []
        try database.query(sql: "SELECT * FROM products") { row in
            guard let id = row["id"] as? String,
                  let namesText = row["names_json"] as? String,
                  let componentsText = row["components_json"] as? String,
                  let namesData = namesText.data(using: .utf8),
                  let names = try? decoder.decode(LocalizedText.self, from: namesData),
                  let componentsData = componentsText.data(using: .utf8),
                  let components = try? decoder.decode([ProductComponent].self, from: componentsData) else {
                return
            }
            var description: [String: String]? = nil
            if let descriptionText = row["description_json"] as? String,
               let data = descriptionText.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                description = json
            }
            var assembly: [String: [String]]? = nil
            if let assemblyText = row["assembly_instructions_json"] as? String,
               let data = assemblyText.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                assembly = json
            }
            items.append(Product(id: id, names: names, description: description, components: components, assemblyInstructions: assembly))
        }
        return items
    }
}

#endif
