//
//  MetadataManager.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

// process video file and extract audio to a temporary file

func setMetadataFFmpeg(workingFile: URL, ffmpegBackupFile: URL) -> URL? {
    log("Entering function", level: .debug)
    let tempAudioFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
    
    let ffmpegCommand = "/opt/homebrew/bin/ffmpeg"
    let arguments = [
        "-y", "-i", "\"\(ffmpegBackupFile.path)\"",
        "-map", "0:v", "-map", "0:a",
        "-codec", "copy",
        "-movflags", "faststart",
        "\"\(workingFile.path)\"",
        "-map", "0:a",
        "-ar", "16000",
        "-ac", "1",
        "-c:a", "pcm_s16le",
        "\"\(tempAudioFile.path)\""
    ]

    let result = runCommand(cmd: ffmpegCommand, arguments: arguments)

    if result.exitCode == 0 {
        return tempAudioFile
    } else {
        log("FFmpeg processing failed for \(workingFile.path): \(result.error)", level: .error)
        return nil
    }
}

// Add metadata to the video file. Automatically creates a backup file.
func setMetadataExiftool(workingFile: URL, exifBackupFile: URL, title: String, dateTime: String) -> Bool {
    log("Entering function", level: .debug)
    
    let cmd = "/opt/homebrew/bin/exiftool"
    let arguments = [
        "-Title=\"\(title)\"",
        "-AllDates=\"\(dateTime)\"",
        "\"\(workingFile.path)\""
    ]

    let result = runCommand(cmd: cmd, arguments: arguments)

    if result.exitCode == 0 {
        if FileManager.default.fileExists(atPath: exifBackupFile.path) {
            return true
        } else {
            log("Expected backup file not found: \(exifBackupFile.path)", level: .warning)
            return false
        }
    } else {
        log("ExifTool processing failed for \(workingFile.path): \(result.error)", level: .error)
        return false
    }
}
