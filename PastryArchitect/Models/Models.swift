import Foundation

public struct LocalizedText: Codable, Equatable {
    public var values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([String: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    private func preferredLanguageCode() -> String {
        if #available(macOS 13.0, iOS 16.0, *) {
            if let identifier = Locale.current.language.languageCode?.identifier {
                return identifier
            }
        }
        if let legacyCode = Locale.current.languageCode {
            return legacyCode
        }
        return "en"
    }

    public func value(for locale: String? = nil) -> String {
        let code = locale ?? preferredLanguageCode()
        if let direct = values[code] { return direct }
        if let english = values["en"] { return english }
        return values.values.first ?? ""
    }
}

public struct CatalogueItem: Identifiable, Codable, Equatable {
    public var id: String
    public var names: LocalizedText
    public var category: String
    public var defaultUnit: String
}

public struct RecipeIngredient: Codable, Equatable, Identifiable {
    public var id: String { catalogueID }
    public var catalogueID: String
    public var quantity: Double?
    public var unit: String?
    public var note: String?
}

public struct Recipe: Identifiable, Codable, Equatable {
    public var id: String
    public var names: LocalizedText
    public var yieldAmount: Double?
    public var yieldUnit: String?
    public var instructions: [String: [String]]
    public var ingredients: [RecipeIngredient]
}

public struct ProductComponent: Codable, Equatable, Identifiable {
    public var id: String { referenceID }
    public var referenceID: String
    public var type: String // "recipe" or "catalogue"
    public var quantity: Double?
    public var unit: String?
}

public struct Product: Identifiable, Codable, Equatable {
    public var id: String
    public var names: LocalizedText
    public var description: [String: String]?
    public var components: [ProductComponent]
    public var assemblyInstructions: [String: [String]]?
}

public enum ImportStatus: String, Codable, Equatable {
    case queued, uploading, processing, writing, completed, error
}

public struct ImportJob: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var fileURL: URL
    public var pageCount: Int?
    public var status: ImportStatus = .queued
    public var progress: Double = 0
    public var message: String = "Queued"
    public var errorDescription: String?
}

public struct ParsedPayload: Codable {
    public var catalogue: [CatalogueItem]
    public var recipes: [Recipe]
    public var products: [Product]
}
