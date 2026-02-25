#if os(macOS)
import SwiftUI

@main
struct KiroShikishaApp: App {
    @State private var agentManager = AgentManager()
    @State private var appStateManager = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(agentManager)
                .environment(appStateManager)
        }
    }
}
#else
@main
struct KiroShikishaApp {
    static func main() {
        print("Kiro Shikisha - macOS application")
        print("Run on macOS for full GUI experience")
    }
}
#endif
