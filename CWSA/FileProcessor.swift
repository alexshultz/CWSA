//
//  FileProcessor.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

// Function to process a single file
func processFile(filePath: URL) {
    log("Entering function", level: .debug)
    log("Starting file processing for \(filePath.path)", level: .info)

    let matchPattern = "S(\\d{4})E(\\d{2})(\\d{2})(\\d{2}) - (.+?)\\.1080p\\.mp4"
    guard let regex = try? NSRegularExpression(pattern: matchPattern) else {
        log("Invalid regular expression", level: .error)
        return
    }

    let filenameStr = filePath.lastPathComponent
    let range = NSRange(location: 0, length: filenameStr.utf16.count)

    if let match = regex.firstMatch(in: filenameStr, options: [], range: range) {
        let baseDirectoryURL = filePath.deletingLastPathComponent()
        let doneFolderPath = baseDirectoryURL.appendingPathComponent("done")
        let originalFile = filePath
        let workingFile = filePath
        let ffmpegBackupFile = filePath.deletingPathExtension().appendingPathExtension("mp4_raw")
        let exifBackupFile = filePath.deletingPathExtension().appendingPathExtension("mp4_original")
        let srtFile = filePath.deletingPathExtension().appendingPathExtension("en.srt")
        let year = (filenameStr as NSString).substring(with: match.range(at: 1))
        let month = (filenameStr as NSString).substring(with: match.range(at: 2))
        let day = (filenameStr as NSString).substring(with: match.range(at: 3))
        let hour = (filenameStr as NSString).substring(with: match.range(at: 4))
        let title = (filenameStr as NSString).substring(with: match.range(at: 5))
        let dateTime = "\(year):\(month):\(day) \(hour):00:00"

        ensureDoneFolderExists(at: doneFolderPath)

        do {
            try FileManager.default.moveItem(at: originalFile, to: ffmpegBackupFile)

            if let audioFileObj = setMetadataFFmpeg(workingFile: workingFile, ffmpegBackupFile: ffmpegBackupFile) {
                moveFileToDoneFolder(fileURL: ffmpegBackupFile, doneFolderPath: doneFolderPath)
                
                if setMetadataExiftool(workingFile: workingFile, exifBackupFile: exifBackupFile, title: title, dateTime: dateTime) {
                    moveFileToDoneFolder(fileURL: exifBackupFile, doneFolderPath: doneFolderPath)
                    updateDatestamp(filename: originalFile)
                    moveFileToDoneFolder(fileURL: originalFile, doneFolderPath: doneFolderPath)

                    switch transcriptionMethod {
                    case .whisper:
                        log("Transcribing with Whisper", level: .debug)
                        let subtitlesCreated = generateSubtitles(audioFileURL: audioFileObj, videoFileURL: filePath, doneFolderPath: doneFolderPath)
                        if subtitlesCreated {
                            updateDatestamp(filename: srtFile, minute: 1)
                            moveFileToDoneFolder(fileURL: srtFile, doneFolderPath: doneFolderPath)
                        } else {
                            log("Subtitle generation failed for \(filePath)", level: .error)
                        }

                    case .speechFramework:
                            log("Transcribing with Speech Framework", level: .debug)
                        let transcriptionService = TranscriptionService()

                        do {
                            // Call transcribeAudioToSRT with await and handle the result
                            let srtText = try await transcriptionService.transcribeAudioToSRT(from: filePath)
                            guard let srtText = srtText else {
                                log("Failed to transcribe audio using Speech framework for \(filePath)", level: .error)
                                return
                            }
                            log("Subtitle txt \(srtText)", level: .debug)
                            let srtFileURL = filePath.deletingPathExtension().appendingPathExtension("srt")
                            writeSRTFile(srtContent: srtText, to: srtFileURL)
                        } catch {
                            log("Error during transcription: \(error.localizedDescription)", level: .error)
                        }
                    }
                    try? FileManager.default.removeItem(at: audioFileObj)
                } else {
                    log("Failed to set metadata using Exiftool for \(workingFile)", level: .error)
                }
            } else {
                log("Failed to process audio metadata for \(workingFile)", level: .error)
            }
        } catch {
            log("Error during file processing or moving file to 'done' folder: \(error)", level: .error)
        }
    } else {
        log("Filename does not match expected pattern for \(filePath)", level: .error)
    }
}

// Function to process a directory
func processDirectory(directory: URL) {
    log("Entering function", level: .debug)
    let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [])
    
    while let file = enumerator?.nextObject() as? URL {
        if file.pathExtension == "mp4" {
            processFile(filePath: file)
        }
    }
}

func processPaths() {
    let paths = CommandLine.arguments.dropFirst()
    for path in paths {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                processDirectory(directory: url)
            } else if url.pathExtension == "mp4" {
                processFile(filePath: url)
            }
        }
    }
}

func moveFileToDoneFolder(fileURL: URL, doneFolderPath: URL) {
    log("Entering function", level: .debug)
    let fileManager = FileManager.default
    let destinationURL = doneFolderPath.appendingPathComponent(fileURL.lastPathComponent)

    do {
        // Create "done" folder if it doesn't exist
        if !fileManager.fileExists(atPath: doneFolderPath.path) {
            try fileManager.createDirectory(at: doneFolderPath, withIntermediateDirectories: true, attributes: nil)
        }

        // Overwrite handling
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Move the file
        try fileManager.moveItem(at: fileURL, to: destinationURL)
    } catch {
        log("Failed to move file to 'done' folder: \(error)", level: .error)
    }
}

func createDoneFolder(at path: URL) throws {
    log("Entering function", level: .debug)
    let doneFolderPath = path.appendingPathComponent("done")
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: doneFolderPath.path) {
        try fileManager.createDirectory(at: doneFolderPath, withIntermediateDirectories: true, attributes: nil)
    }
}

func ensureDoneFolderExists(at path: URL) {
    log("Entering function", level: .debug)
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path.path) {
        do {
            try fileManager.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            log("Failed to create 'done' folder: \(error)", level: .error)
        }
    }
}

func writeSRTFile(srtContent: String, to url: URL) {
    do {
        try srtContent.write(to: url, atomically: true, encoding: .utf8)
        log("SRT file created successfully at \(url.path)", level: .info)
    } catch {
        log("Failed to write SRT file to \(url.path): \(error.localizedDescription)", level: .error)
    }
}
