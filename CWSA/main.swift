//
//  main.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

// Main function to start processing
func main() {
    setupAndVerifyWhisperEnv()
    runCommandInCondaEnvironment(envName: "whisper", command: "echo Is whisper running $WHISPER_ENV")

    let arguments = CommandLine.arguments
    // Basic argument parsing. To be expanded for full functionality
    let paths = Array(arguments.dropFirst()) // Drop the first element which is the executable path

    for path in paths {
        let fileURL = URL(fileURLWithPath: path)
        if fileURL.hasDirectoryPath {
            processDirectory(directory: fileURL)
        } else {
            processFile(filePath: fileURL)
        }
    }
}

// Entry point
main()
