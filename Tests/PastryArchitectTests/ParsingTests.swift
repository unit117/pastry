import XCTest
@testable import PastryArchitect

final class ParsingTests: XCTestCase {
    func testDecodePayload() throws {
        let json = """
        {
            "catalogue": [{"id": "butter", "names": {"en": "Butter"}, "category": "Dairy", "defaultUnit": "g"}],
            "recipes": [{
                "id": "cream",
                "names": {"en": "Pastry Cream"},
                "yieldAmount": 1.5,
                "yieldUnit": "kg",
                "instructions": {"en": ["Heat milk", "Whisk eggs"]},
                "ingredients": [{"catalogueID": "butter", "quantity": 100, "unit": "g"}]
            }],
            "products": [{
                "id": "tart",
                "names": {"en": "Fruit Tart"},
                "description": {"en": "Delicate tart"},
                "components": [{"referenceID": "cream", "type": "recipe", "quantity": 1, "unit": "batch"}],
                "assemblyInstructions": {"en": ["Bake shell", "Fill cream"]}
            }]
        }
        """
        let data = json.data(using: .utf8)!
        let payload = try JSONDecoder().decode(ParsedPayload.self, from: data)
        XCTAssertEqual(payload.catalogue.first?.names.value(), "Butter")
        XCTAssertEqual(payload.recipes.first?.ingredients.first?.catalogueID, "butter")
        XCTAssertEqual(payload.products.first?.components.first?.referenceID, "cream")
    }

#if canImport(SQLite3)
    func testDatabaseInsertions() throws {
        let tempDB = NSTemporaryDirectory().appending("test_inventory.db")
        let store = try DataStore(databasePath: tempDB)
        let payload = ParsedPayload(
            catalogue: [CatalogueItem(id: "sugar", names: LocalizedText(values: ["en": "Sugar"]), category: "Dry", defaultUnit: "g")],
            recipes: [Recipe(id: "syrup", names: LocalizedText(values: ["en": "Simple Syrup"]), yieldAmount: 1, yieldUnit: "L", instructions: ["en": ["Boil"]], ingredients: [RecipeIngredient(catalogueID: "sugar", quantity: 500, unit: "g", note: nil)])],
            products: [Product(id: "drink", names: LocalizedText(values: ["en": "Sweet Drink"]), description: ["en": ""], components: [ProductComponent(referenceID: "syrup", type: "recipe", quantity: 1, unit: "batch")], assemblyInstructions: ["en": ["Mix"]])]
        )
        try store.save(payload: payload)
        let catalogue = try store.fetchCatalogue()
        let recipes = try store.fetchRecipes()
        let products = try store.fetchProducts()
        XCTAssertEqual(catalogue.count, 1)
        XCTAssertEqual(recipes.first?.ingredients.first?.catalogueID, "sugar")
        XCTAssertEqual(products.first?.components.first?.referenceID, "syrup")
    }
#endif
}
