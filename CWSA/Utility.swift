//
//  Utility.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

func runCommand(cmd: String, arguments: [String], condaEnv: String? = nil) -> (output: String, error: String, exitCode: Int32) {
    let commandWithArgs = "\(cmd) " + arguments.joined(separator: " ")
    let fullCommand = condaEnv != nil ? "source activate \(condaEnv!) && \(commandWithArgs) && source deactivate" : commandWithArgs

    // Print the command that will be executed
    print("Executing command: \(fullCommand)")

    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/bash") // Adjust if necessary
    process.arguments = ["-c", fullCommand]
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ("", error.localizedDescription, -1)
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""
    let error = String(data: errorData, encoding: .utf8) ?? ""

    return (output, error, process.terminationStatus)
}

func updateDatestamp(filename: URL, minute: Int = 0) {
    let datePattern = "S(\\d{4})E(\\d{2})(\\d{2})(\\d{2})"
    let regex = try! NSRegularExpression(pattern: datePattern)
    let filenameStr = filename.lastPathComponent
    let range = NSRange(location: 0, length: filenameStr.utf16.count)
    
    if let match = regex.firstMatch(in: filenameStr, options: [], range: range) {
        let year = Int((filenameStr as NSString).substring(with: match.range(at: 1)))!
        let month = Int((filenameStr as NSString).substring(with: match.range(at: 2)))!
        let day = Int((filenameStr as NSString).substring(with: match.range(at: 3)))!
        let hour = Int((filenameStr as NSString).substring(with: match.range(at: 4)))!
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        let newDate = Calendar.current.date(from: components)!
        
        let attributes: [FileAttributeKey : Any] = [
            .creationDate: newDate,
            .modificationDate: newDate
        ]
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: filename.path)
    }
}
