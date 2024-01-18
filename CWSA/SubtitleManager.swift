//
//  SubtitleManager.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

func generateSubtitles(audioFileURL: URL, videoFileURL: URL, doneFolderPath: URL) -> Bool {
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
    print("Executing command: \(commandString)")

    let result = runCommand(cmd: cmd, arguments: arguments, condaEnv: "whisper")

    print("Command Output: \(result.output)")
    print("Command Error: \(result.error)")

    let externalSubtitlePathStr = videoFileURL.deletingPathExtension().appendingPathExtension("en.srt").path
    if FileManager.default.fileExists(atPath: externalSubtitlePathStr) {
        return true
    } else {
        print("Subtitle file not found: \(externalSubtitlePathStr)")
        return false
    }
}
