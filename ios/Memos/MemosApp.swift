import SwiftUI
import UIKit

@main
struct MemosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serverManager = ServerManager.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    @StateObject private var keepAliveManager = KeepAliveManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
                .environmentObject(backgroundTaskManager)
                .environmentObject(keepAliveManager)
                .onAppear {
                    serverManager.startServer()
                }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("App launched")

        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()

        // Update background refresh status
        BackgroundTaskManager.shared.updateBackgroundRefreshStatus()

        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Handle background URL session events
        BackgroundURLSessionManager.shared.backgroundCompletionHandler = completionHandler
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("App will terminate")
    }
}
