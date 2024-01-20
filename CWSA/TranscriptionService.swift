//
//  TranscriptionService.swift
//  CWSA
//
//  Created by Alex Shultz on 1/18/24.
//

import Foundation
import Speech
import AVFoundation

enum TranscriptionMethod {
    case whisper
    case speechFramework
}

// may be overridden by command line option
var transcriptionMethod: TranscriptionMethod = .whisper // .speechFramework Or .whisper

class TranscriptionService {
    // Declare some variables as  properties of the class
    private var lastUpdateTime = Date()
    private var isTranscriptionComplete = false
    private var progressTimer: Timer?

    init() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // Ensure authorization is granted
        }
    }
    
    @MainActor
    func transcribeAudioToSRT(from audioURL: URL, completion: @escaping (String?) -> Void) async {
        let totalDuration = try? await getAudioDuration(url: audioURL)

        // Reset the last update time at the start of transcription
        lastUpdateTime = Date()
        isTranscriptionComplete = false

        // Setup the speech recognition
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            log("Speech recognizer is not available.", level: .error)
            completion(nil)
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let strongSelf = self else { return }

            if let error = error {
                log("Speech recognition error: \(error.localizedDescription)", level: .error)
                completion(nil)
                return
            }

            guard let result = result else {
                log("No transcription result.", level: .error)
                completion(nil)
                return
            }

            // Update the last update time when new results are received
            strongSelf.lastUpdateTime = Date()

            if result.isFinal {
                strongSelf.isTranscriptionComplete = true
                let srtFormat = strongSelf.formatToSRT(result.bestTranscription)
                completion(srtFormat)
                strongSelf.invalidateTimer()
            }
        }

        // Setup the timer for regular updates
        setupProgressTimer()
    }

    private func setupProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }

                let now = Date()
                if now.timeIntervalSince(strongSelf.lastUpdateTime) >= 5 {
                    // Report the latest progress based on the last updated time
                    log("Transcription progress update", level: .info)
                }

                // Stop the timer if the transcription process is complete
                if strongSelf.isTranscriptionComplete {
                    strongSelf.invalidateTimer()
                }
            }
        }
    }

    private func invalidateTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    
    private func formatToSRT(_ transcription: SFTranscription) -> String {
        log("Entering function", level: .debug)
        var srtString = ""
        var index = 1

        for segment in transcription.segments {
            let startTime = segment.timestamp
            let endTime = segment.duration + startTime
            let text = segment.substring

            srtString += "\(index)\n"
            srtString += "\(formatTime(startTime)) --> \(formatTime(endTime))\n"
            srtString += "\(text)\n\n"

            index += 1
        }

        return srtString
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        log("Entering function", level: .debug)
        let hours = Int(time / 3600)
        let minutes = Int(time / 60) % 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - floor(time)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

}

func getAudioDuration(url: URL) async throws -> TimeInterval {
    log("Entering function", level: .debug)
    let asset = AVURLAsset(url: url)

    do {
        let duration: CMTime = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    } catch {
        // Handle or throw the error
        throw error
    }
}

func startSpeechRecognition(audioURL: URL) async {
    log("Entering function", level: .debug)
    log("Starting speech recognition for \(audioURL.lastPathComponent)", level: .debug)

    do {
        let totalDuration = try await getAudioDuration(url: audioURL)
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audioURL)

        recognizer?.recognitionTask(with: request, resultHandler: { (result, error) in
            guard let result = result, error == nil else {
                log("Speech recognition error: \(error?.localizedDescription ?? "Unknown error")", level: .error)
                return
            }

            if let lastSegment = result.bestTranscription.segments.last {
                let currentTime = lastSegment.timestamp + lastSegment.duration
                let progress = (currentTime / totalDuration) * 100
                log("Recognition progress: \(progress)%", level: .debug)
            }

            if result.isFinal {
                log("Final transcription: \(result.bestTranscription.formattedString)", level: .info)
            }
        })
    } catch {
        log("Error fetching audio duration: \(error.localizedDescription)", level: .error)
    }
}
