//
//  main.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

var currentLogLevel: LogLevel = .info // Default log level

// Main function to start processing
func main() {
    log("Entering function", level: .debug)
    let arguments = CommandLine.arguments

    // Argument parsing
    if let levelIndex = arguments.firstIndex(of: "-logLevel"), levelIndex + 1 < arguments.count {
        let levelString = arguments[levelIndex + 1]
        switch levelString.lowercased() {
        case "debug":
            currentLogLevel = .debug
        case "info":
            currentLogLevel = .info
        case "warning":
            currentLogLevel = .warning
        case "error":
            currentLogLevel = .error
        default:
            print("Invalid log level specified. Using default level: INFO")
        }
    }
    if let index = arguments.firstIndex(of: "-transcriptionMethod"), index + 1 < arguments.count {
        let method = arguments[index + 1]
        transcriptionMethod = (method == "whisper") ? .whisper : .speechFramework
    }

    // Find the file paths to process
    let paths = Array(arguments.dropFirst()) // Drop the first element which is the executable path
    
    // Filter out non-file paths
    let validFilePaths = paths.filter { arg in
        !arg.starts(with: "-") && FileManager.default.fileExists(atPath: arg)
    }

    // Log if no valid files are found
    if validFilePaths.isEmpty {
        log("No valid file paths found to process.", level: .warning)
    } else {
        // Process each valid file path
        for path in validFilePaths {
            let fileURL = URL(fileURLWithPath: path)
            if fileURL.hasDirectoryPath {
                processDirectory(directory: fileURL)
            } else {
                let doneFolderPath = fileURL.deletingLastPathComponent() // Calculate doneFolderPath as the base folder path of the file
                processFile(filePath: fileURL, doneFolderPath: doneFolderPath)
            }
        }
    }
}

// Entry point
main()
