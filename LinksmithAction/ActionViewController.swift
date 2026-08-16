import AppKit
import LinksmithCore

@objc(ActionViewController)
final class ActionViewController: NSViewController {
    private let settings = SharedSettings()
    private let recents = RecentDestinationStore()
    private let service = SymlinkService()
    private var hasStarted = false

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 110))
        let progress = NSProgressIndicator()
        progress.style = .spinning
        progress.startAnimation(nil)
        progress.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "Preparing destination chooser…")
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(progress)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            progress.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            progress.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: 12),
        ])
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        waitForExtensionContext(attemptsRemaining: 50)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        startRequestIfNeeded()
    }

    private func waitForExtensionContext(attemptsRemaining: Int) {
        guard hasStarted == false else { return }
        if extensionContext != nil {
            startRequestIfNeeded()
        } else if attemptsRemaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.waitForExtensionContext(attemptsRemaining: attemptsRemaining - 1)
            }
        } else {
            let error = LinksmithActionError.extensionContextUnavailable
            extensionContext?.cancelRequest(withError: error)
            showInlineError(error)
        }
    }

    private func startRequestIfNeeded() {
        guard hasStarted == false, let context = extensionContext else { return }
        hasStarted = true
        FinderSelectionLoader.load(from: context) { [weak self, weak context] result in
            DispatchQueue.main.async {
                guard let self, let context else { return }
                switch result {
                case .failure(let error): context.cancelRequest(withError: error)
                case .success(let sources): self.chooseDestinationAndCreateLinks(for: sources, context: context)
                }
            }
        }
    }

    private func chooseDestinationAndCreateLinks(for sources: [URL], context: NSExtensionContext) {
        guard let destination = DestinationChooser(recentURLs: recents.resolvedURLs()).choose() else {
            context.cancelRequest(withError: CocoaError(.userCancelled))
            return
        }

        let scopedURLs = sources + [destination]
        let access = scopedURLs.map { $0.startAccessingSecurityScopedResource() }
        defer {
            for (url, didStart) in zip(scopedURLs, access) where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            _ = try service.createLinks(to: sources, in: destination, kind: settings.symlinkKind)
            try recents.remember(destination)
            context.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            context.cancelRequest(withError: error)
        }
    }

    private func showInlineError(_ error: Error) {
        view.subviews.compactMap { $0 as? NSProgressIndicator }.forEach { $0.stopAnimation(nil) }
        view.subviews.compactMap { $0 as? NSTextField }.first?.stringValue = error.localizedDescription
    }
}
