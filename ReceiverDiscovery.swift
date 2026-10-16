import Foundation
import Combine
import Network

@MainActor
final class ReceiverDiscovery: ObservableObject {
    @Published private(set) var receivers: [Receiver] = []
    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var isBrowsing = false

    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private let serviceType = "_mirrorcast._tcp"

    func start() {
        guard browser == nil else { return }
        state = .discovering
        isBrowsing = true

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let newBrowser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        browser = newBrowser

        newBrowser.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.isBrowsing = true
                    self.state = self.receivers.isEmpty ? .discovering : .found(self.receivers.count)
                case .failed(let error):
                    self.state = .error(error.localizedDescription)
                    self.isBrowsing = false
                    self.browser?.cancel()
                    self.browser = nil
                case .cancelled:
                    self.isBrowsing = false
                default: break
                }
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.update(results) }
        }
        newBrowser.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        state = .disconnected
    }

    private func update(_ results: Set<NWBrowser.Result>) {
        var discovered: [Receiver] = []
        for result in results {
            guard case let .service(name, type, domain, _) = result.endpoint else { continue }
            let id = "\(name).\(type).\(domain)"
            discovered.append(Receiver(id: id, name: name, endpoint: "\(name).\(domain)", port: nil))
        }
        receivers = discovered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        state = receivers.isEmpty ? (isBrowsing ? .discovering : .disconnected) : .found(receivers.count)
    }
}
