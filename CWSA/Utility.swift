//
//  Utility.swift
//  CWSA
//
//  Created by Alex Shultz on 1/16/24.
//

import Foundation

func runCommand(cmd: String, arguments: [String], condaEnv: String? = nil) -> (output: String, error: String, exitCode: Int32) {
    log("Entering function", level: .debug)
    let commandWithArgs = "\(cmd) " + arguments.joined(separator: " ")
    
    // Assuming the .zshrc file is in the user's home directory
    let homeDirectory = NSHomeDirectory()
    let zshrcPath = "\(homeDirectory)/.zshrc"

    var fullCommand = commandWithArgs
    if let condaEnv = condaEnv {
        // Construct the command string to run within the Conda environment
        fullCommand = """
        source \(zshrcPath)
        conda activate \(condaEnv)
        \(commandWithArgs)
        conda deactivate
        """
    }

    // Print the command that will be executed
    print("Executing command: \(fullCommand)")

    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Using zsh
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
    log("Entering function", level: .debug)
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

func manageCondaEnvironment(envName: String, verificationCommand: String) {
    log("Entering function", level: .debug)
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")

    // Source .zshrc (or the relevant shell init file) before using the conda command
    // Replace /path/to/.zshrc with the actual path to your .zshrc file
    let commandString = "source $HOME/.zshrc && conda activate \(envName) && \(verificationCommand) && conda deactivate"

    process.arguments = ["-c", commandString]

    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        print(output ?? "No output")
    } catch {
        log("Failed to manage conda environment: \(error)", level: .error)
    }
}

func setupAndVerifyWhisperEnv() {
    log("Entering function", level: .debug)
    let process = Process()
    let pipe = Pipe()

    // Assuming the .zshrc file is in the user's home directory
    let homeDirectory = NSHomeDirectory()
    let zshrcPath = "\(homeDirectory)/.zshrc"

    // Construct the command string
    let commandString = """
    source \(zshrcPath)
    conda activate whisper
    mkdir -p $(conda info --envs | grep whisper | awk '{print $2}')/etc/conda/activate.d
    mkdir -p $(conda info --envs | grep whisper | awk '{print $2}')/etc/conda/deactivate.d
    echo 'export WHISPER_ENV=true' > $(conda info --envs | grep whisper | awk '{print $2}')/etc/conda/activate.d/env_vars.sh
    echo 'unset WHISPER_ENV' > $(conda info --envs | grep whisper | awk '{print $2}')/etc/conda/deactivate.d/env_vars.sh
    chmod +x $(conda info --envs | grep whisper | awk '{print $2}')/etc/conda/activate.d/env_vars.sh
    chmod +x $(conda info --envs | grep whisper | awk '{print $2}')/etc/conda/deactivate.d/env_vars.sh
    conda deactivate
    conda activate whisper
    echo $WHISPER_ENV
    conda deactivate
    """

    // Print the exact command for debugging
    log("Executing command: \(commandString)", level: .debug)

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", commandString]

    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        print(output ?? "No output")
    } catch {
        log("Failed to setup and verify WHISPER_ENV: \(error)", level: .error)
    }
}

func runCommandInCondaEnvironment(envName: String, command: String) {
    log("Entering function", level: .debug)
    let process = Process()
    let pipe = Pipe()

    // Assuming the .zshrc file is in the user's home directory
    let homeDirectory = NSHomeDirectory()
    let zshrcPath = "\(homeDirectory)/.zshrc"

    // Construct the command string
    let commandString = """
    source \(zshrcPath)
    conda activate \(envName)
    \(command)
    conda deactivate
    """

    // Print the exact command for debugging
    log("Executing command: \(commandString)", level: .debug)

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", commandString]

    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        log(output ?? "No output", level: .info)
    } catch {
        log("Failed to run command in \(envName) environment: \(error)", level: .error)
    }
}

enum LogLevel: Int {
    case debug = 1, info, warning, error
}

func log(_ message: String, level: LogLevel, file: String = #file, function: String = #function, line: Int = #line) {
    guard level >= currentLogLevel else { return }

    let fileName = (file as NSString).lastPathComponent
    let logMessage = "\(Date()): [\(level)] [\(fileName):\(function):\(line)] - \(message)"
    print(logMessage)
}

extension LogLevel: Comparable {
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
