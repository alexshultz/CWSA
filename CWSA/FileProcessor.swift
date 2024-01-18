//
//  FileProcessor.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

// Function to process a single file
func processFile(filePath: URL) {
    let matchPattern = "S(\\d{4})E(\\d{2})(\\d{2})(\\d{2}) - (.+?)\\.1080p\\.mp4"
    guard let regex = try? NSRegularExpression(pattern: matchPattern) else {
        print("Invalid regular expression")
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
                    let subtitlesCreated = generateSubtitles(audioFileURL: audioFileObj, videoFileURL: filePath, doneFolderPath: doneFolderPath)
                    try? FileManager.default.removeItem(at: audioFileObj)
                    
                    if subtitlesCreated {
                        updateDatestamp(filename: srtFile, minute: 1)
                        moveFileToDoneFolder(fileURL: srtFile, doneFolderPath: doneFolderPath)
                    } else {
                        print("Subtitle generation failed for \(filePath)")
                    }
                } else {
                    print("Failed to set metadata using Exiftool for \(workingFile)")
                }
            } else {
                print("Failed to process audio metadata for \(workingFile)")
            }
        } catch {
            print("Error during file processing or moving file to 'done' folder: \(error)")
        }
    } else {
        print("Filename does not match expected pattern for \(filePath)")
    }
}

// Function to process a directory
func processDirectory(directory: URL) {
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
        print("Failed to move file to 'done' folder: \(error)")
    }
}

func createDoneFolder(at path: URL) throws {
    let doneFolderPath = path.appendingPathComponent("done")
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: doneFolderPath.path) {
        try fileManager.createDirectory(at: doneFolderPath, withIntermediateDirectories: true, attributes: nil)
    }
}

func ensureDoneFolderExists(at path: URL) {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path.path) {
        do {
            try fileManager.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create 'done' folder: \(error)")
        }
    }
}
