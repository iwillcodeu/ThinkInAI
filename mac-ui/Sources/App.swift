import SwiftUI

@main
struct DeepSeekHarnessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var server = ServerManager.shared

    var body: some Scene {
        Window("DeepSeek Harness", id: "main") {
            ContentView(server: server)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 840)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            ServerManager.shared.stopIfOwned()
        }
    }
}
