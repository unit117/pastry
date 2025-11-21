# Pastry Architect

Pastry Architect is a macOS SwiftUI application for importing pastry PDF books, extracting structured recipe data with Google AI Studio (Gemini 2.5 Flash), and browsing the normalized catalogue/recipe/product data locally. It is designed with Setapp-quality polish, clear progress feedback, and a resilient offline-friendly architecture.

## Features
- Drag & drop or open-panel PDF imports with a queued workflow and human-readable status updates.
- Configurable system prompt for Gemini to return language-aware JSON covering catalogue items, recipes, and products.
- Local SQLite persistence at `~/Library/Application Support/PastryArchitect/inventory.db` using a minimal wrapper.
- Browsing panes for catalogue, recipes, and products with search and detail views.
- Preferences for Google AI Studio API key storage (Keychain), database location, and login-item toggle stub.

## Project Structure
- `Models/` – Core data models and value types.
- `Networking/` – `GoogleAIStudioClient` abstraction for uploading PDFs and receiving parsed payloads.
- `Persistence/` – `SQLiteDatabase` helper and `DataStore` for CRUD operations.
- `ViewModels/` – `AppViewModel` orchestrates imports, datastore writes, and search.
- `Views/` – SwiftUI views for import queue, catalogue/recipe/product browsing, and preferences.
- `Tests/` – JSON decoding and database write/read tests.

## Building
1. Ensure Xcode 15+ (macOS 13+) with Swift 5.9 or later.
2. Open the package in Xcode or run `swift build` from the repository root.
3. Set your Google AI Studio API key in Preferences before starting imports.

> Note: SwiftUI-based files are wrapped in `#if canImport(SwiftUI)` so the core package can build and tests can run in non-macOS CI environments. The application UI still requires macOS to run.

## Testing
Run the unit suite:

```bash
swift test
```

The included tests validate JSON decoding into models and SQLite persistence for the parsed payload. On Linux containers without SwiftUI, the tests should now pass because UI sources are conditionally excluded.

## Database Schema
The app creates tables matching the normalized payload:

```sql
CREATE TABLE IF NOT EXISTS catalogue (
    id TEXT PRIMARY KEY,
    names_json TEXT NOT NULL,
    category TEXT NOT NULL,
    defaultUnit TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS recipes (
    id TEXT PRIMARY KEY,
    names_json TEXT NOT NULL,
    yieldAmount REAL,
    yieldUnit TEXT,
    instructions_json TEXT NOT NULL,
    ingredients_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    names_json TEXT NOT NULL,
    description_json TEXT,
    components_json TEXT NOT NULL,
    assembly_instructions_json TEXT
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
```

## Configuration
- **API Key**: Stored via `KeychainHelper` under the `com.pastry.architect` service name.
- **Database Path**: Defaults to `~/Library/Application Support/PastryArchitect/inventory.db` and can be overridden in settings.
- **System Prompt**: `AppViewModel.systemPrompt` provides the full instructions sent with each upload.

## Future Enhancements
- Menu bar status item for quick access and last import summary.
- Richer editing of catalogue/recipe/product entries.
- Auto-start login item implementation for macOS.
