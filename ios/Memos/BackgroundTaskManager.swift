import Foundation
import UIKit
import BackgroundTasks
import Combine

class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()

    @Published var backgroundRefreshStatus: UIBackgroundRefreshStatus = .available
    @Published var lastBackgroundRefresh: Date?

    // Task identifiers
    private let backgroundRefreshTaskID = "com.usememos.ios.refresh"
    private let backgroundProcessingTaskID = "com.usememos.ios.processing"

    private init() {
        updateBackgroundRefreshStatus()
    }

    // MARK: - Registration

    func registerBackgroundTasks() {
        // Register background app refresh
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundRefreshTaskID,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }

        // Register background processing
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundProcessingTaskID,
            using: nil
        ) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }

        print("Background tasks registered")
    }

    // MARK: - Scheduling

    func scheduleBackgroundTasks() {
        scheduleBackgroundRefresh()
        scheduleBackgroundProcessing()
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled")
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }

    private func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: backgroundProcessingTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background processing scheduled")
        } catch {
            print("Could not schedule background processing: \(error)")
        }
    }

    // MARK: - Task Handlers

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        print("Background refresh task started")

        // Schedule next refresh
        scheduleBackgroundRefresh()

        // Create task for keeping server alive
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BackgroundServerOperation()

        task.expirationHandler = {
            queue.cancelAllOperations()
            print("Background refresh expired")
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            self.lastBackgroundRefresh = Date()
        }

        queue.addOperation(operation)
    }

    private func handleBackgroundProcessing(task: BGProcessingTask) {
        print("Background processing task started")

        // Schedule next processing task
        scheduleBackgroundProcessing()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BackgroundServerOperation()

        task.expirationHandler = {
            queue.cancelAllOperations()
            print("Background processing expired")
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        queue.addOperation(operation)
    }

    // MARK: - Status

    func updateBackgroundRefreshStatus() {
        backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
    }

    func canRunInBackground() -> Bool {
        return backgroundRefreshStatus == .available
    }
}

// MARK: - Background Operation

class BackgroundServerOperation: Operation {
    override func main() {
        guard !isCancelled else { return }

        // Ensure server is running
        if !ServerManager.shared.isRunning {
            ServerManager.shared.startServer()
        }

        // Keep alive for as long as iOS allows
        let semaphore = DispatchSemaphore(value: 0)

        // Wait for cancellation or timeout (iOS typically gives 30 seconds)
        _ = semaphore.wait(timeout: .now() + 25)

        print("Background server operation completed")
    }
}
