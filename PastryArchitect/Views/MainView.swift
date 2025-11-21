import SwiftUI

struct MainView: View {
    @StateObject var viewModel: AppViewModel
    @State private var selection: SidebarItem = .imports

    var body: some View {
        NavigationView {
            sidebar
            content
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: viewModel.importFromPanel) {
                    Label("Import PDFs…", systemImage: "square.and.arrow.down")
                }
                statusIndicator
                Spacer()
                searchField
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases, id: \.self) { item in
                Label(item.title, systemImage: item.icon)
                    .tag(item)
            }
        }
        .listStyle(SidebarListStyle())
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .imports:
            ImportQueueView(jobs: $viewModel.importJobs)
                .frame(minWidth: 500, minHeight: 400)
                .overlay(importDropArea)
        case .catalogue:
            CatalogueView(items: viewModel.catalogue, searchText: $viewModel.searchText) {
                Task { await viewModel.refreshData() }
            }
        case .recipes:
            RecipesView(recipes: viewModel.recipes)
        case .products:
            ProductsView(products: viewModel.products)
        }
    }

    private var importDropArea: some View {
        ImportDropView { urls in
            viewModel.handleDroppedFiles(urls: urls)
        }
    }

    private var statusIndicator: some View {
        Label(viewModel.statusMessage, systemImage: viewModel.isImporting ? "arrow.triangle.2.circlepath" : "checkmark.circle")
            .foregroundColor(viewModel.isImporting ? .accentColor : .secondary)
    }

    private var searchField: some View {
        TextField("Search", text: $viewModel.searchText)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onSubmit {
                Task { await viewModel.refreshData() }
            }
    }
}

enum SidebarItem: CaseIterable {
    case imports, catalogue, recipes, products

    var title: String {
        switch self {
        case .imports: return "Imports"
        case .catalogue: return "Catalogue"
        case .recipes: return "Recipes"
        case .products: return "Products"
        }
    }

    var icon: String {
        switch self {
        case .imports: return "tray.and.arrow.down"
        case .catalogue: return "list.bullet"
        case .recipes: return "book"
        case .products: return "shippingbox"
        }
    }
}
