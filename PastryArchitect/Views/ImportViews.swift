import SwiftUI

struct ImportDropView: View {
    var onDrop: ([URL]) -> Void

    var body: some View {
        VStack {
            Text("Drag pastry PDF here to extract recipes")
                .font(.title3)
                .padding()
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
            providers.loadFileURLs { urls in
                onDrop(urls)
            }
            return true
        }
    }
}

struct ImportQueueView: View {
    @Binding var jobs: [ImportJob]

    var body: some View {
        List(jobs) { job in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(job.fileURL.lastPathComponent)
                        .font(.headline)
                    if let pages = job.pageCount {
                        Text("\(pages) pages")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: job.status)
                }
                ProgressView(value: job.progress)
                Text(job.message)
                    .foregroundColor(job.status == .error ? .red : .secondary)
                if let error = job.errorDescription {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct StatusBadge: View {
    let status: ImportStatus
    var body: some View {
        Label(status.rawValue.capitalized, systemImage: icon)
            .padding(6)
            .background(Capsule().fill(Color.accentColor.opacity(0.1)))
    }
    private var icon: String {
        switch status {
        case .queued: return "clock"
        case .uploading: return "arrow.up.circle"
        case .processing: return "sparkles"
        case .writing: return "square.and.pencil"
        case .completed: return "checkmark.circle"
        case .error: return "xmark.octagon"
        }
    }
}

private extension [NSItemProvider] {
    func loadFileURLs(completion: @escaping ([URL]) -> Void) {
        var collected: [URL] = []
        let group = DispatchGroup()
        for provider in self {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        collected.append(url)
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            completion(collected)
        }
    }
}
