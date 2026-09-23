import Foundation
import AVFoundation

func reconstructSession(atPath path: String) {
    let url = URL(fileURLWithPath: path)
    let journalURL = url.appendingPathComponent("events.journal")
    
    print("--- Session Reconstruction ---")
    print("Session Directory: \(url.path)")
    
    var journalValid = false
    var sessionStopped = false
    
    // 1. Check Journal
    if let data = try? Data(contentsOf: journalURL),
       let contents = String(data: data, encoding: .utf8) {
        let lines = contents.split(separator: "\n")
        print("Found \(lines.count) journal events.")
        
        for line in lines {
            if line.contains("SESSION_STOPPED") {
                sessionStopped = true
            }
        }
        journalValid = true
    } else {
        print("WARNING: events.journal is missing or unreadable.")
    }
    
    if journalValid && !sessionStopped {
        print("WARNING: Session did not terminate cleanly (Missing SESSION_STOPPED event). Likely a crash or kill -9.")
    } else if journalValid && sessionStopped {
        print("Session terminated cleanly.")
    }
    
    // 2. Reconstruct from Audio Files
    print("\nScanning for durable audio chunks...")
    do {
        let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        let audioFiles = files.filter { $0.pathExtension == "caf" }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        
        if audioFiles.isEmpty {
            print("No audio chunks found.")
            return
        }
        
        var totalFrames: AVAudioFramePosition = 0
        var format: AVAudioFormat?
        
        for file in audioFiles {
            do {
                let audioFile = try AVAudioFile(forReading: file)
                if format == nil {
                    format = audioFile.processingFormat
                }
                totalFrames += audioFile.length
                print(" - Recovered: \(file.lastPathComponent) (\(audioFile.length) frames)")
            } catch {
                print(" - Error reading chunk \(file.lastPathComponent): \(error)")
            }
        }
        
        if let fmt = format {
            let durationSeconds = Double(totalFrames) / fmt.sampleRate
            print("\nReconstruction Successful:")
            print("Total Recovered Duration: \(String(format: "%.2f", durationSeconds)) seconds")
            print("Sample Rate: \(fmt.sampleRate) Hz")
            print("Channels: \(fmt.channelCount)")
        }
        
    } catch {
        print("Error reading session directory: \(error)")
    }
}

if CommandLine.arguments.count < 2 {
    print("Usage: swift SessionReconstructor.swift <path_to_session_directory>")
    exit(1)
}

reconstructSession(atPath: CommandLine.arguments[1])
