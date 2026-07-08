//
//  STempItem.swift
//  Status
//
//  Created by bi119aTe5hXk on 2022/04/17.
//  Copyright © 2022 bi119aTe5hXk. All rights reserved.
//
// https://github.com/freedomtan/sensors/

import Foundation
import Cocoa
import Darwin


internal class STempFanItem: StatusItem {
    private typealias ThermalReading = (name: String, value: Float)

    private var fanCount: Int = 0
    private let faninfo = FanInfo.init()
    
    private var refreshTimer: Timer?
    
    private let fixedImageWidth = CGFloat(56)
    private let imageView: NSImageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 56, height: 26))
    
    var enabled: Bool{ return Preferences[.shouldShowTempFanItem] }
    
    var title: String  { return "temp" }
    
    var view: NSView { return imageView }
    
    init() {
        
        fanCount = faninfo.getNumberOfFans()
        
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
        let temperatureText: String
        if let temperature = selectedTemperature() {
            temperatureText = "\(String(format:"%.01f", temperature)) °C"
        } else {
            temperatureText = "-- °C"
        }

        let menuBarImage = createMenuBarImage(upper: temperatureText, lower: currentFanText())

        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = menuBarImage
        }
    }

    private var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }

    private func selectedTemperature() -> Float? {
        let readings = thermalReadings().filter { $0.value > 0 && $0.value < 125 }
        guard !readings.isEmpty else { return nil }

        let cpuReadings = readings.filter { reading in
            let name = reading.name.lowercased()
            let isCPU = name.contains("cpu") || name.contains("pacc") || name.contains("eacc")
            let isClearlyOther = name.contains("gpu") || name.contains("ane") || name.contains("battery") || name.contains("skin") || name.contains("palm")
            return isCPU && !isClearlyOther
        }

        let selectedReadings = cpuReadings.isEmpty ? readings : cpuReadings
        return selectedReadings.map { $0.value }.max()
    }

    private func thermalReadings() -> [ThermalReading] {
        guard let snapshots = thermalSensorSnapshots() as? [[String: Any]] else { return [] }
        return snapshots.compactMap { item in
            guard let name = item["name"] as? String else { return nil }

            if let value = item["value"] as? NSNumber {
                return (name: name, value: value.floatValue)
            }
            if let value = item["value"] as? Float {
                return (name: name, value: value)
            }
            if let value = item["value"] as? Double {
                return (name: name, value: Float(value))
            }
            return nil
        }
    }

    private func currentFanText() -> String? {
    if fanCount == 0 {
        fanCount = faninfo.getNumberOfFans()
    }
    guard fanCount > 0 else { return nil }

    var curMaxFanSpeed = 0
    for id in 0..<fanCount {
        let currentFanSpeed = faninfo.getCurrentFanSpeed(id: id)
        if curMaxFanSpeed < currentFanSpeed {
            curMaxFanSpeed = currentFanSpeed
        }
    }

    return "\(curMaxFanSpeed) RPM"
}

    func didLoad() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.reload()
        })
    }
    
    func didUnload() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    /**
     * Creates an attributed string that can be drawn on the menu bar image.
     */
    private func createAttributedString(value: String, color: NSColor, fontSize: CGFloat = 9) -> NSAttributedString {
    // create the attributed string
    let attrString = NSMutableAttributedString(string: value)

    // define the font for the number value and the unit
    let font = NSFont.systemFont(ofSize: fontSize)

    // add the attributes
    attrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: attrString.length ))
    let fontColor = color//ThemeManager.isDarkTheme() ? NSColor.white : NSColor.black
    attrString.addAttribute(.foregroundColor, value: fontColor, range: NSRange(location: 0, length: attrString.length))

    return attrString
}

/**

     * Returns the image that can be rendered on the menu bar.
     */
    private func createMenuBarImage(upper: String, lower: String?) -> NSImage? {
        let upperStrAttr = self.createAttributedString(value: upper, color: NSColor.white, fontSize: lower == nil ? 12 : 9)
        let lowerStrAttr = lower.map { self.createAttributedString(value: $0, color: NSColor.white) }

        // create the menu bar image.
        let lowerWidth = lowerStrAttr?.size().width ?? 0
        let textWidth = fixedImageWidth
        let menuBarImage = NSImage(
            size: NSSize(
                width: textWidth,
                height: CGFloat(20.0)
            )
        )

        // focus the image to render the bandwidth values
        menuBarImage.lockFocus()

        // draw the upper string
        let upperStringSize = upperStrAttr.size()
        if let lowerStrAttr = lowerStrAttr {
            upperStrAttr.draw(
                at: NSPoint(
                    x: textWidth - upperStringSize.width,
                    y: menuBarImage.size.height - 9 // this value was found by trail and error
                )
            )

            // draw the lower string
            let lowerStringsize = lowerStrAttr.size()
            // y value was found by trail and error
            lowerStrAttr.draw(at: NSPoint(x: textWidth - lowerStringsize.width, y: -1))
        } else {
            upperStrAttr.draw(
                at: NSPoint(
                    x: textWidth - upperStringSize.width,
                    y: (menuBarImage.size.height - upperStringSize.height) / 2
                )
            )
        }

        // unlock the focous of drawing
        menuBarImage.unlockFocus()

        return menuBarImage
    }
}

