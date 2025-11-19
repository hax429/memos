import Foundation

/// Manages background URL sessions for uploading/downloading when app is backgrounded
class BackgroundURLSessionManager: NSObject {
    static let shared = BackgroundURLSessionManager()

    private var session: URLSession!
    private let sessionIdentifier = "com.usememos.ios.background"

    var backgroundCompletionHandler: (() -> Void)?

    override private init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.shouldUseExtendedBackgroundIdleMode = true

        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        print("Background URL session configured")
    }

    // MARK: - Upload/Download Methods

    func upload(data: Data, to url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let task = session.uploadTask(with: request, from: data)
        task.resume()

        print("Background upload task started: \(task.taskIdentifier)")
    }

    func download(from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let task = session.downloadTask(with: url)
        task.resume()

        print("Background download task started: \(task.taskIdentifier)")
    }
}

// MARK: - URLSessionDelegate

extension BackgroundURLSessionManager: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - URLSessionTaskDelegate

extension BackgroundURLSessionManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Background task failed: \(error.localizedDescription)")
        } else {
            print("Background task completed successfully")
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundURLSessionManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Download finished to: \(location)")
        // Move file to permanent location if needed
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        print("Download progress: \(progress * 100)%")
    }
}
