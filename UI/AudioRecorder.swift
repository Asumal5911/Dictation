import AVFoundation
import Foundation

final class QuickAudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private let fileURL: URL
    private(set) var isRecording = false
    private var recordingStartTime: Date?

    override init() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quick_dictation.wav")
        super.init()
    }

    static var hasMicrophonePermission: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    @discardableResult
    func startRecording() -> Bool {
        guard !isRecording else { return true }

        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            Self.requestMicrophonePermission { _ in }
        } else if status == .denied || status == .restricted {
            print("❌ Microphone permission is denied in macOS System Settings")
            return false
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
        ]

        do {
            try? FileManager.default.removeItem(at: fileURL)
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record() else {
                print("❌ Microphone did not begin recording")
                return false
            }
            self.recorder = recorder
            isRecording = true
            recordingStartTime = Date()
            print("🎙️ Recording clean 16 kHz mono PCM for speech recognition")
            return true
        } catch {
            recorder = nil
            print("❌ Failed to start recording: \(error)")
            return false
        }
    }

    func currentAudioLevel() -> Float {
        guard let recorder, isRecording else { return 0.0 }
        recorder.updateMeters()
        let avgPower = recorder.averagePower(forChannel: 0) // Typically -160 dB to 0 dB
        let minDb: Float = -50.0
        if avgPower <= minDb { return 0.0 }
        if avgPower >= 0.0 { return 1.0 }
        return (avgPower - minDb) / (-minDb)
    }

    func stopRecording(completion: @escaping (Data?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }

        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        recorder?.stop()
        recorder = nil
        isRecording = false
        print("🎙️ QuickAudioRecorder stopped (duration: \(String(format: "%.2f", duration))s)")

        // Brief delay for AVAudioRecorder to flush file buffers to disk
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            do {
                let data = try Data(contentsOf: self.fileURL)
                completion(data)
            } catch {
                print("❌ Failed to read recorded audio: \(error)")
                completion(nil)
            }
        }
    }
}
