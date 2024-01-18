//
//  SubtitleManager.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

func generateSubtitles(audioFileURL: URL, videoFileURL: URL, doneFolderPath: URL) {
    let modelFileStr = "/Users/alex/GitHub/whisper.cpp/models/ggml-medium.en.bin"
    let srtPathStr = videoFileURL.deletingPathExtension().appendingPathExtension("en").path

    let cmd = "/Users/alex/GitHub/whisper.cpp/main"
    let arguments = [
        "-m", "\"\(modelFileStr)\"",
        "-osrt",
        "-p", "6",
        "-f", "\"\(audioFileURL.path)\"",
        "-of", "\"\(srtPathStr)\""
    ]

    // Constructing the command string for debugging purposes
    let commandString = "\(cmd) " + arguments.joined(separator: " ")
    print("Executing command: \(commandString)")

    let result = runCommand(cmd: cmd, arguments: arguments)

    // Printing output and error for debugging
    print("Command Output: \(result.output)")
    print("Command Error: \(result.error)")

    let externalSubtitlePathStr = videoFileURL.deletingPathExtension().appendingPathExtension("en.srt").path
    if FileManager.default.fileExists(atPath: externalSubtitlePathStr) {
        updateDatestamp(filename: URL(fileURLWithPath: externalSubtitlePathStr), minute: 1)
        moveFileToDoneFolder(fileURL: URL(fileURLWithPath: externalSubtitlePathStr), doneFolderPath: doneFolderPath)
    } else {
        print("Subtitle file not found: \(externalSubtitlePathStr)")
    }
}
