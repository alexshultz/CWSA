//
//  SubtitleManagerWhisper.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

func generateSubtitles(audioFileURL: URL, videoFileURL: URL, doneFolderPath: URL) -> Bool {
    log("Entering function", level: .debug)
    let modelFileStr = "$HOME/GitHub/whisper.cpp/models/ggml-tiny.en.bin"
    let srtPathStr = videoFileURL.deletingPathExtension().appendingPathExtension("en").path

    let cmd = "/Users/alex/GitHub/whisper.cpp/main"
    let arguments = [
        "-m", "\"\(modelFileStr)\"",
        "-osrt",
        "-p", "6",
        "-f", "\"\(audioFileURL.path)\"",
        "-of", "\"\(srtPathStr)\""
    ]

    let commandString = "\(cmd) " + arguments.joined(separator: " ")
    log("Executing command: \(commandString)", level: .debug)

    let result = runCommand(cmd: cmd, arguments: arguments, condaEnv: "whisper")

    log("Command Output: \(result.output)", level: .debug)
    log("Command Error: \(result.error)", level: .error)

    let externalSubtitlePathStr = videoFileURL.deletingPathExtension().appendingPathExtension("en.srt").path
    if FileManager.default.fileExists(atPath: externalSubtitlePathStr) {
        return true
    } else {
        log("Subtitle file not found: \(externalSubtitlePathStr)", level: .warning)
        return false
    }
}
