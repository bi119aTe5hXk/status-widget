//
//  SNetworkItem.swift
//  Status
//
//  Created by bi119aTe5hXk on 2021/08/22.
//  Copyright © 2021 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Defaults

internal class SNetworkItem: StatusItem {
    
    
    
    var enabled: Bool{ return Defaults[.shouldShowNetworkItem] }
    
    var title: String  { return "network" }
    
    var view: NSView { return NSView.init() }
    
    init() {
        didLoad()
        reload()
    }
    deinit {
        didUnload()
    }
    
    func action() {
        /** nothing do to here */
    }
    
    func reload() {
        
    }
    func didLoad() {
        
    }
    
    func didUnload() {
        
    }
    
    
    
    // MARK: -
        // MARK: Private Variables
        /// The total uploaded and downloaded bytes that were read during the last update interval of the app.
        /// This variable is used to calculate the network bandwidth using [getNetworkBandwidth()](x-source-tag://getNetworkBandwidth())
        private var lastTotalTransmittedBytes: (up: UInt64, down: UInt64) = (up: 0, down: 0)

        // MARK: -
        // MARK: Instance Functions
        /**
         * Returns the current bandwidth of the given interface in bytes.
         *
         *  - Parameter interface: The name of the interface.
         *
         *  - Tag: getNetworkBandwidth()
         */


    func getNetworkBandwidth(interface: String) -> (up: UInt64, down: UInt64) {
            // get the total transmitted bytes of the interfafe
            let transmittedBytes = getTotalTransmittedBytesOf(interface: interface)

            // get the transmitted byte since the last update
            var upBytes: UInt64 = 0
            var downBytes: UInt64 = 0
            // if the lastTotalTransmittedBytes is greater than the current transmitted bytes, the currently used interface was changed
            if transmittedBytes.up >= lastTotalTransmittedBytes.up {
                upBytes = transmittedBytes.up - lastTotalTransmittedBytes.up
            }
            if transmittedBytes.down >= lastTotalTransmittedBytes.down {
                downBytes = transmittedBytes.down - lastTotalTransmittedBytes.down
            }

            // divide the bandwidth by the update interval to get the average of one update duration
            let upBandwidth = upBytes / UInt64(1)
            let downBandwidth = downBytes / UInt64(1)

            // update the total transmitted bytes
            lastTotalTransmittedBytes = transmittedBytes

            return (up: upBandwidth, down: downBandwidth)
        }

        /**
         * Returns the total transmitted bytes of an interface since booting the machine.
         */
        func getTotalTransmittedBytesOf(interface: String) -> (up: UInt64, down: UInt64) {
            // create the process to call the netstat commandline tool
            guard let commandOutput = executeCommand(launchPath: "/usr/bin/env", arguments: ["netstat", "-bdnI", interface]) else {
                print("An error occurred while executing the netstat command")
                return (up: 0, down: 0)
            }

            // split the lines of the output
            let lowerCaseOutput = commandOutput.lowercased()
            let lines = lowerCaseOutput.split(separator: "\n")

            // check that there are more than one lines. If not the network interface is unknown or something else went wrong
            if lines.count <= 1 {
                print("Something went wrong while parsing the network bandwidth command output")
                return (up: 0, down: 0)
            }

            // create a regex to replace multiple spaces with just one space
            guard let regex = try? NSRegularExpression(pattern: "/ +/g") else {
                print("Failed to create the regex")
                return (up: 0, down: 0)
            }
            // take the second line since the first line are just the column names of the table
            let firstLine = String(lines[1])
            // replace all whitespaces to just one whitespace
            let cleanedFirstLine = regex.stringByReplacingMatches(in: firstLine, options: [], range: NSRange(location: 0, length: firstLine.count), withTemplate: " ")
            // split the line at the spaces to get the columns of the table
            let columns = cleanedFirstLine.split(separator: " ")

            // get the total down- and uploaded bytes
            guard let totalDownBytes = UInt64(String(columns[6])), let totalUpBytes = UInt64(String(columns[9])) else {
                print("Something went wrong while retrieving the down- and uploaded bytes")
                return (up: 0, down: 0)
            }

            return (up: totalUpBytes, down: totalDownBytes)
        }

        /**
         * Returns the name of the currently used network interface as a string. If something went wrong the default network interface "en0" is returned.
         */
        func getCurrentlyUsedInterface() -> String {
            // create the process for the command
            guard let commandOutput = executeCommand(
                launchPath: "/bin/bash",
                arguments: ["-c", "route get 0.0.0.0 2>/dev/null | grep interface: | awk '{print $2}'"]
                ) else {
                print("An error occurred while executing the command to get the currently used network interface")
                return "en0"
            }

            print("Output of the network interface command: \n\(commandOutput)")

            // get the interface name
            let interfaceName = commandOutput.trimmingCharacters(in: .whitespacesAndNewlines)

            return interfaceName.isEmpty ? "en0" : interfaceName
        }


    func executeCommand(launchPath: String, arguments: [String]) -> String? {
        let task = Process()
        let outputPipe = Pipe()

        // execute the command
        task.launchPath = launchPath
        task.arguments = arguments
        task.standardOutput = outputPipe
        task.launch()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: String.Encoding.utf8) else {
            print("An error occurred while casting the command output to a string")
            return nil
        }

        task.waitUntilExit()

        return output
    }

    func convertToCorrectUnit(bytes: UInt64) -> (value: Double, unit: ByteUnit) {
        if bytes < 1000 {
            return (value: Double(bytes), unit: ByteUnit.Byte)
        }
        let exp = Int(log2(Double(bytes)) / log2(1000.0))
        let unitString = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
        let unit = ByteUnit(rawValue: unitString) ?? ByteUnit.Gigabyte
        let number = Double(bytes) / pow(1000, Double(exp))

        return (value: number, unit: unit)
    }


    enum ByteUnit: String, Comparable, CaseIterable {
            static func < (lhs: ByteUnit, rhs: ByteUnit) -> Bool {
                let caseArray = self.allCases

                var lhsIndex: Int?
                var rhsIndex: Int?
                for index in 0..<caseArray.count {
                    if caseArray[index] == lhs {
                        lhsIndex = index
                    }
                    if caseArray[index] == rhs {
                        rhsIndex = index
                    }
                }

                if lhsIndex == nil || rhsIndex == nil {
                    print("Something went wrong while comparing the two ByteUnits \(lhs) and \(rhs)")
                    return false
                }

                return lhsIndex! < rhsIndex!
            }

            case Byte = "B"
            case Kilobyte = "KB"
            case Megabyte = "MB"
            case Gigabyte = "GB"
            case Terabyte = "TB"
            case Petabyte = "PB"
            case Exabyte = "EB"
        }

    
}


