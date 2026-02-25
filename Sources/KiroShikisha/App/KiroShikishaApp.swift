#if os(macOS)
import SwiftUI

@main
struct KiroShikishaApp: App {
    @State private var agentManager = AgentManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(agentManager)
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
