import Foundation
import UniformTypeIdentifiers

enum FinderSelectionLoader {
    static func load(from context: NSExtensionContext, completion: @escaping (Result<[URL], Error>) -> Void) {
        let providers = context.inputItems.compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
        guard providers.isEmpty == false else { completion(.failure(LinksmithActionError.noFileURLs)); return }

        let group = DispatchGroup()
        let completionGate = CompletionGate(completion: completion)
        let lock = NSLock()
        var indexedURLs: [(Int, URL)] = []
        var firstError: Error?
        for (index, provider) in providers.enumerated() {
            group.enter()
            let record: (URL?, Error?) -> Void = { url, error in
                defer { group.leave() }
                lock.lock()
                defer { lock.unlock() }
                if let url { indexedURLs.append((index, url)) }
                else if firstError == nil { firstError = error ?? LinksmithActionError.unreadableFileURL }
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    record(fileURL(from: item), error)
                }
            } else if let type = provider.registeredTypeIdentifiers.first(where: {
                UTType($0)?.conforms(to: .item) == true
            }) {
                provider.loadInPlaceFileRepresentation(forTypeIdentifier: type) { url, _, error in
                    record(url, error)
                }
            } else {
                record(nil, LinksmithActionError.unreadableFileURL)
            }
        }
        group.notify(queue: .global()) {
            let urls = indexedURLs.sorted { $0.0 < $1.0 }.map(\.1)
            completionGate.finish(urls.isEmpty ? .failure(firstError ?? LinksmithActionError.unreadableFileURL) : .success(urls))
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            completionGate.finish(.failure(LinksmithActionError.selectionTimedOut))
        }
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return nil
    }
}

enum LinksmithActionError: LocalizedError {
    case noFileURLs, unreadableFileURL, selectionTimedOut, extensionContextUnavailable
    var errorDescription: String? {
        switch self {
        case .noFileURLs: "Create Symlink did not receive any Finder files or folders."
        case .unreadableFileURL: "Create Symlink could not access the Finder selection."
        case .selectionTimedOut: "Finder did not provide the selected files in time. Please close this action and try again."
        case .extensionContextUnavailable: "Finder did not attach an extension context to Create Symlink."
        }
    }
}

private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasFinished = false
    private let completion: (Result<[URL], Error>) -> Void

    init(completion: @escaping (Result<[URL], Error>) -> Void) {
        self.completion = completion
    }

    func finish(_ result: Result<[URL], Error>) {
        lock.lock()
        guard hasFinished == false else { lock.unlock(); return }
        hasFinished = true
        lock.unlock()
        completion(result)
    }
}
