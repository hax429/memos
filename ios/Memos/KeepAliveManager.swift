import Foundation
import UIKit
import AVFoundation
import Combine

/// Manages keeping the app alive in the background using legitimate iOS techniques
class KeepAliveManager: ObservableObject {
    static let shared = KeepAliveManager()

    @Published var isKeepAliveEnabled = false
    @Published var backgroundTimeRemaining: TimeInterval = 0

    private var audioPlayer: AVAudioPlayer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var timer: Timer?

    private init() {
        setupAudioSession()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playback category to allow background audio
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(false)
            print("Audio session configured")
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Keep Alive Control

    func startKeepAlive() {
        guard !isKeepAliveEnabled else { return }

        // Start background task
        beginBackgroundTask()

        // Setup silent audio playback (only when user explicitly enables)
        setupSilentAudio()

        isKeepAliveEnabled = true
        startBackgroundTimeMonitor()

        print("Keep alive started")
    }

    func stopKeepAlive() {
        guard isKeepAliveEnabled else { return }

        stopSilentAudio()
        endBackgroundTask()
        stopBackgroundTimeMonitor()

        isKeepAliveEnabled = false

        print("Keep alive stopped")
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Silent Audio (Optional)

    private func setupSilentAudio() {
        // Only use this if user explicitly enables "Keep Running in Background"
        // This creates a 1-second silent audio file and loops it
        guard let silenceURL = createSilenceFile() else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.01 // Very quiet (but not 0, to avoid optimization)

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)

            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            print("Silent audio started")
        } catch {
            print("Failed to setup silent audio: \(error)")
        }
    }

    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    private func createSilenceFile() -> URL? {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = AVAudioFrameCount(44100) // 1 second

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        // Fill with silence (zeros)
        if let data = buffer.floatChannelData {
            memset(data[0], 0, Int(frameCount) * MemoryLayout<Float>.size)
        }

        // Save to temp file
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("silence.caf")

        do {
            let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try file.write(from: buffer)
            return fileURL
        } catch {
            print("Failed to create silence file: \(error)")
            return nil
        }
    }

    // MARK: - Background Time Monitor

    private func startBackgroundTimeMonitor() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBackgroundTimeRemaining()
        }
    }

    private func stopBackgroundTimeMonitor() {
        timer?.invalidate()
        timer = nil
        backgroundTimeRemaining = 0
    }

    private func updateBackgroundTimeRemaining() {
        DispatchQueue.main.async {
            self.backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
        }
    }
}
