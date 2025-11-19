import Foundation
import Combine
import UIKit
import Mobile // This will be the gomobile framework

class ServerManager: ObservableObject {
    static let shared = ServerManager()

    @Published var isRunning = false
    @Published var serverURL: String?
    @Published var error: String?
    private var isStarting = false
    @Published var allowNetworkAccess = false {
        didSet {
            if oldValue != allowNetworkAccess && isRunning {
                // Restart server with new settings
                stopServer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startServer()
                }
            }
        }
    }
    @Published var keepRunningInBackground = false {
        didSet {
            if keepRunningInBackground {
                KeepAliveManager.shared.startKeepAlive()
            } else {
                KeepAliveManager.shared.stopKeepAlive()
            }
            saveSettings()
        }
    }

    private let port: Int = 5230
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSettings()
        setupAppLifecycleObservers()
    }

    func startServer() {
        guard !isRunning && !isStarting else {
            print("Server already running or starting, skipping start")
            return
        }

        isStarting = true
        defer { isStarting = false }

        do {
            // Get the documents directory
            let documentsPath = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).path

            let dataDir = MobileGetDataDirectory(documentsPath)

            // Determine bind address based on network access setting
            let addr = allowNetworkAccess ? "0.0.0.0" : ""

            var serverError: NSError?
            let url = MobileNewServer(dataDir, port, addr, "prod", &serverError)

            if let error = serverError {
                throw error
            }

            DispatchQueue.main.async {
                // Update APIClient with the actual server URL BEFORE setting isRunning
                // This ensures authentication uses the correct URL
                if let url = url {
                    APIClient.shared.updateBaseURL(url)
                }

                self.serverURL = url
                self.isRunning = true
                self.error = nil
            }

            print("Server started at: \(url ?? "unknown")")

        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isRunning = false
            }
            print("Failed to start server: \(error)")
        }
    }

    func stopServer() {
        guard isRunning else { return }

        do {
            var stopError: NSError?
            MobileStopServer(&stopError)

            if let error = stopError {
                throw error
            }

            DispatchQueue.main.async {
                self.isRunning = false
                self.serverURL = nil
            }

            print("Server stopped")

        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
            }
            print("Failed to stop server: \(error)")
        }
    }

    func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // WiFi interface
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                              &hostname, socklen_t(hostname.count),
                              nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }

        freeifaddrs(ifaddr)
        return address
    }

    // MARK: - App Lifecycle

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleWillEnterForeground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleWillTerminate()
            }
            .store(in: &cancellables)
    }

    private func handleDidEnterBackground() {
        print("App entering background")

        if keepRunningInBackground {
            // Background execution is enabled - keep server running
            print("Keep running in background is enabled")
            BackgroundTaskManager.shared.scheduleBackgroundTasks()
        } else {
            // Default behavior - stop server
            print("Stopping server for background")
            stopServer()
        }

        saveServerState()
    }

    private func handleWillEnterForeground() {
        print("App entering foreground")

        // Restore server if it was running before
        if shouldRestoreServer() {
            startServer()
        }
    }

    private func handleWillTerminate() {
        print("App terminating")
        stopServer()
        KeepAliveManager.shared.stopKeepAlive()
    }

    // MARK: - State Persistence

    private func saveServerState() {
        let state: [String: Any] = [
            "isRunning": isRunning,
            "allowNetworkAccess": allowNetworkAccess,
            "keepRunningInBackground": keepRunningInBackground
        ]
        UserDefaults.standard.set(state, forKey: "ServerState")
        print("Server state saved")
    }

    private func shouldRestoreServer() -> Bool {
        guard let state = UserDefaults.standard.dictionary(forKey: "ServerState") else {
            return false
        }
        return state["isRunning"] as? Bool ?? false
    }

    private func saveSettings() {
        let settings: [String: Any] = [
            "allowNetworkAccess": allowNetworkAccess,
            "keepRunningInBackground": keepRunningInBackground
        ]
        UserDefaults.standard.set(settings, forKey: "ServerSettings")
    }

    private func loadSettings() {
        guard let settings = UserDefaults.standard.dictionary(forKey: "ServerSettings") else {
            return
        }
        allowNetworkAccess = settings["allowNetworkAccess"] as? Bool ?? false
        keepRunningInBackground = settings["keepRunningInBackground"] as? Bool ?? false
    }
}
