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


internal class STempFanItem: StatusItem {
    //var currentNames: [Any] = [],
        //voltageNames: [Any] = [],
        //thermalNames: [Any] = []
    
    //var currentValues: [Any] = [],
        //voltageValues: [Any] = [],
    var    thermalValues: [Any] = []
    
    private var fanCount: Int = 0
    let faninfo = FanInfo.init()
    
    private var refreshTimer: Timer?
    
    private let imageView: NSImageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 50, height: 26))
    
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
//        currentNames = currentArray()
//        voltageNames = voltageArray()
//        thermalNames = thermalArray()
                
//        currentValues = returnCurrentValues()
//        voltageValues = returnVoltageValues()
        thermalValues = returnThermalValues()
        
//        print(currentNames)
//        print(currentValues)
//        print("-------------------------")
//        print(voltageNames)
//        print(voltageValues)
//        print("-------------------------")
//        print(thermalNames)
//        print(thermalValues)
        
        var sumtemp:Float = 0.0, count = 0

        for item in thermalValues{
            let value = item as! Float
            if value > 0 {
                sumtemp = sumtemp + value
                count += 1
            }
        }
        let avgtemp = sumtemp / Float(count)
//        print(avgtemp)
        
    
        var curMaxFanSpeed = 0
        for id in 0..<fanCount {
            // get the fan speed for the current fan
            let currentFanSpeed = faninfo.getCurrentFanSpeed(id: id)
            //let maxFanSpeed = faninfo.getMaxFanSpeed(id: id)
            //let minFanSpeed = faninfo.getMinFanSpeed(id: id)
            if curMaxFanSpeed < currentFanSpeed {
                curMaxFanSpeed = currentFanSpeed
            }
        }
        print(curMaxFanSpeed)
        
        
        let menuBarImage = createMenuBarImage(upper: "\(String(format:"%.01f", avgtemp)) °C", lower: "\(curMaxFanSpeed) RPM")
         
        
        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = menuBarImage
        }
        
    
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
    private func createAttributedString(value: String, color: NSColor) -> NSAttributedString {
        // create the attributed string
        let attrString = NSMutableAttributedString(string: value)

        // define the font for the number value and the unit
        let font = NSFont.systemFont(ofSize: 9)

        // add the attributes
        attrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: attrString.length ))
        let fontColor = color//ThemeManager.isDarkTheme() ? NSColor.white : NSColor.black
        attrString.addAttribute(.foregroundColor, value: fontColor, range: NSRange(location: 0, length: attrString.length))

        return attrString
    }
    
    /**
     * Returns the image that can be rendered on the menu bar.
     */
    private func createMenuBarImage(upper: String, lower: String) -> NSImage? {
        
        let upperStrAttr = self.createAttributedString(value: upper, color:NSColor.white)
        let lowerStrAttr = self.createAttributedString(value: lower, color:NSColor.white)
        
        

        // create the menu bar image.
        let textWidth = max(CGFloat(40), max(upperStrAttr.size().width, lowerStrAttr.size().width))
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
        upperStrAttr.draw(
            at: NSPoint(
                x:  textWidth - upperStringSize.width,
                y: menuBarImage.size.height - 9 // this value was found by trail and error
            )
        )

        // draw the lower string
        let lowerStringsize = lowerStrAttr.size()
        // y value was found by trail and error
        lowerStrAttr.draw(at: NSPoint(x: textWidth - lowerStringsize.width, y: -1))


        // unlock the focous of drawing
        menuBarImage.unlockFocus()

        return menuBarImage
    }
    
    
}
