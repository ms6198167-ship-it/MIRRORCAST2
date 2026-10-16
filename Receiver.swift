import Foundation

struct Receiver: Identifiable, Hashable {
    let id: String
    let name: String
    let endpoint: String
    let port: UInt16?
    let type: String

    init(id: String, name: String, endpoint: String, port: UInt16?, type: String = "MirrorCast receiver") {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.port = port
        self.type = type
    }
}

enum ConnectionState: Equatable {
    case disconnected
    case discovering
    case found(Int)
    case error(String)

    var title: String {
        switch self {
        case .disconnected: return "Not connected"
        case .discovering: return "Searching nearby"
        case .found(let count): return "\(count) receiver\(count == 1 ? "" : "s") found"
        case .error: return "Discovery issue"
        }
    }
}
