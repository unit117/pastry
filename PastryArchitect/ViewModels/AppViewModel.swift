import Foundation
#if canImport(SwiftUI)
import Combine
import SwiftUI
import CoreGraphics

@MainActor
final class AppViewModel: ObservableObject {
    @Published var importJobs: [ImportJob] = []
    @Published var catalogue: [CatalogueItem] = []
    @Published var recipes: [Recipe] = []
    @Published var products: [Product] = []
    @Published var statusMessage: String = "Idle"
    @Published var isImporting: Bool = false
    @Published var searchText: String = ""

    private let dataStore: DataStore
    private let client: GoogleAIStudioClient
    private var cancellables = Set<AnyCancellable>()

    init(dataStore: DataStore = try! DataStore(), keychain: KeychainHelper = .shared) {
        self.dataStore = dataStore
        self.client = GoogleAIStudioClient(apiKeyProvider: { try keychain.apiKey() })
        Task { await refreshData() }
    }

    func refreshData() async {
        do {
            catalogue = try dataStore.fetchCatalogue(search: searchText)
            recipes = try dataStore.fetchRecipes()
            products = try dataStore.fetchProducts()
        } catch {
            statusMessage = "DB Error: \(error.localizedDescription)"
        }
    }

    func handleDroppedFiles(urls: [URL]) {
        let jobs = urls.map { ImportJob(fileURL: $0, pageCount: nil) }
        importJobs.append(contentsOf: jobs)
        processQueue()
    }

    func importFromPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["pdf"]
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.handleDroppedFiles(urls: panel.urls)
        }
    }

    func processQueue() {
        guard !isImporting else { return }
        guard let job = importJobs.first(where: { $0.status == .queued }) else { return }
        Task { await process(job: job) }
    }

    private func update(job: ImportJob) {
        if let idx = importJobs.firstIndex(where: { $0.id == job.id }) {
            importJobs[idx] = job
        }
    }

    private func setStatus(_ job: ImportJob, status: ImportStatus, progress: Double, message: String, error: String? = nil) {
        var mutable = job
        mutable.status = status
        mutable.progress = progress
        mutable.message = message
        mutable.errorDescription = error
        update(job: mutable)
    }

    private func loadPDFData(url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    private func systemPrompt(for fileName: String) -> String {
        "You are extracting pastry recipes from \(fileName). Normalize into catalogue, recipes, and products JSON."
    }

    private func removeJob(_ job: ImportJob) {
        importJobs.removeAll { $0.id == job.id }
    }

    private func finishJob(_ job: ImportJob) {
        var updated = job
        updated.status = .completed
        updated.progress = 1
        updated.message = "Completed"
        update(job: updated)
        Task { await refreshData() }
    }

    private func failJob(_ job: ImportJob, error: Error) {
        var updated = job
        updated.status = .error
        updated.message = "Error"
        updated.errorDescription = error.localizedDescription
        update(job: updated)
        statusMessage = error.localizedDescription
    }

    private func markImporting(_ flag: Bool) {
        isImporting = flag
        statusMessage = flag ? "Importing" : "Idle"
    }

    private func nextJob(after current: ImportJob) -> ImportJob? {
        importJobs.first { $0.status == .queued }
    }

    private func updateProgress(for job: ImportJob, status: ImportStatus, value: Double, message: String) {
        setStatus(job, status: status, progress: value, message: message)
    }

    private func pdfPageCount(url: URL) -> Int? {
        guard let doc = CGPDFDocument(url as CFURL) else { return nil }
        return doc.numberOfPages
    }

    private func jobWithPageCount(_ job: ImportJob) -> ImportJob {
        var updated = job
        updated.pageCount = pdfPageCount(url: job.fileURL)
        update(job: updated)
        return updated
    }

    private func process(job: ImportJob) async {
        markImporting(true)
        var workingJob = jobWithPageCount(job)
        updateProgress(for: workingJob, status: .uploading, value: 0.1, message: "Uploading…")
        guard let data = loadPDFData(url: workingJob.fileURL) else {
            failJob(workingJob, error: NSError(domain: "File", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read PDF"]))
            markImporting(false)
            return
        }
        do {
            let payload = try await client.upload(pdfData: data, fileName: workingJob.fileURL.lastPathComponent, systemPrompt: systemPrompt(for: workingJob.fileURL.lastPathComponent))
            updateProgress(for: workingJob, status: .processing, value: 0.6, message: "Processing response…")
            try dataStore.save(payload: payload)
            updateProgress(for: workingJob, status: .writing, value: 0.9, message: "Writing to database…")
            finishJob(workingJob)
        } catch {
            failJob(workingJob, error: error)
        }
        markImporting(false)
        if let next = nextJob(after: workingJob) {
            await process(job: next)
        }
    }
}
#endif
