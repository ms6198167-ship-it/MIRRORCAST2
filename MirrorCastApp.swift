import SwiftUI

@main
struct MirrorCastApp: App {
    @StateObject private var discovery = ReceiverDiscovery()

    var body: some Scene {
        WindowGroup {
            HomeDashboard()
                .environmentObject(discovery)
                .preferredColorScheme(nil)
        }
    }
}
