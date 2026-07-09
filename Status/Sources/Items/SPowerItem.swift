//
//  SPowerItem.swift
//  Pock
//
//  Created by Pierluigi Galdi on 23/02/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import AppKit
import IOKit
import IOKit.ps

private enum PowerDisplayMode: Int, CaseIterable {
    case percentage
    case timeToEmpty
    case timeToFull
    case power

    mutating func advance() {
        self = PowerDisplayMode(rawValue: (rawValue + 1) % PowerDisplayMode.allCases.count) ?? .percentage
    }
}

private struct SPowerStatus {
    var isConnected = false
    var isCharging = false
    var isCharged = false
    var currentValue = 0
    var timeToEmpty: Int?
    var timeToFull: Int?
    var amperageMilliamps: Int?
    var voltageMillivolts: Int?
}

internal class SPowerItem: StatusItem {

    /// Core
    private var refreshTimer: Timer?
    private var powerStatus = SPowerStatus()
    private var displayMode: PowerDisplayMode = .percentage
    private var shouldShowBatteryIcon: Bool {
        return Preferences[.shouldShowBatteryIcon]
    }
    private var shouldShowBatteryPercentage: Bool {
        return Preferences[.shouldShowBatteryPercentage]
    }

    /// UI
    private let containerView = StatusItemView(frame: .zero)
    private let stackView = NSStackView(frame: .zero)
    private let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
    private let bodyView = NSView(frame: NSRect(x: 2, y: 5, width: 21, height: 8))
    private let valueLabel = NSTextField(labelWithString: "-%")
    private let detailLabel = NSTextField(labelWithString: "")
    private let secondaryDetailLabel = NSTextField(labelWithString: "")

    init() {
        print("[Status]: init SPowerItem")
        didLoad()
    }

    deinit {
        didUnload()
        print("[Status]: deinit SPowerItem")
    }

    func didLoad() {
        containerView.item = self
        bodyView.wantsLayer = true
        bodyView.layer?.cornerRadius = 1
        configureLabels()
        configureStackView()
        reload()
        refreshTimer = Timer.scheduledTimer(timeInterval: 1, target: self, repeats: true, action: { [weak self] in
            self?.reload()
        })
    }

    func didUnload() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    var enabled: Bool { return Preferences[.shouldShowPowerItem] }

    var title: String { return "power" }

    var view: NSView { return containerView }

    func action() {
        displayMode.advance()
        updateDisplay()
    }

    private func configureLabels() {
        for label in [valueLabel, detailLabel, secondaryDetailLabel] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .regular)
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 34).isActive = true
        }
    }

    private func configureStackView() {
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .fillProportionally
        stackView.spacing = 0
        stackView.detachesHiddenViews = true
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(detailLabel)
        stackView.addArrangedSubview(secondaryDetailLabel)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    @objc func reload() {
        var status = SPowerStatus()
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                as? [String: Any] else { continue }

            status.currentValue = info[kIOPSCurrentCapacityKey] as? Int ?? status.currentValue
            status.isCharging = info[kIOPSIsChargingKey] as? Bool ?? status.isCharging
            status.isCharged = info[kIOPSIsChargedKey] as? Bool ?? status.isCharged
            if let sourceState = info[kIOPSPowerSourceStateKey] as? String {
                status.isConnected = sourceState == kIOPSACPowerValue
            }
            status.timeToEmpty = validMinutes(info[kIOPSTimeToEmptyKey] as? Int)
            status.timeToFull = validMinutes(info[kIOPSTimeToFullChargeKey] as? Int)
        }

        if let battery = smartBatteryProperties() {
            status.timeToEmpty = status.timeToEmpty ?? validMinutes(number(battery["AvgTimeToEmpty"]))
            status.timeToFull = status.timeToFull ?? validMinutes(number(battery["AvgTimeToFull"]))
            status.amperageMilliamps = signedNumber(battery["InstantAmperage"] ?? battery["Amperage"])
            status.voltageMillivolts = number(battery["Voltage"] ?? battery["AppleRawBatteryVoltage"])
        }

        powerStatus = status
        updateIcon(value: status.currentValue)
        updateDisplay()
    }

    private func smartBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return nil
        }
        return properties?.takeRetainedValue() as? [String: Any]
    }

    private func number(_ value: Any?) -> Int? {
        return (value as? NSNumber)?.intValue
    }

    private func signedNumber(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        let bits = UInt32(truncatingIfNeeded: number.uint64Value)
        return Int(Int32(bitPattern: bits))
    }

    private func validMinutes(_ value: Int?) -> Int? {
        guard let value = value, value > 0, value < 65_535 else { return nil }
        return value
    }

    private func updateDisplay() {
        switch displayMode {
        case .percentage:
            valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            valueLabel.isHidden = !shouldShowBatteryPercentage
            detailLabel.isHidden = true
            secondaryDetailLabel.isHidden = true
            iconView.isHidden = !shouldShowBatteryIcon
            valueLabel.stringValue = "\(powerStatus.currentValue)%"
        case .timeToEmpty:
            showTextMode(title: "USE",
                         subtitle: "TIME",
                         detail: powerStatus.isConnected || powerStatus.isCharged
                            ? "--" : format(minutes: powerStatus.timeToEmpty))
        case .timeToFull:
            showTextMode(title: "CHG",
                         subtitle: "TIME",
                         detail: powerStatus.isCharging ? format(minutes: powerStatus.timeToFull) : "--")
        case .power:
            let power = formatPower()
            showTextMode(title: power.title, subtitle: "POWER", detail: power.detail)
        }
    }

    private func showTextMode(title: String, subtitle: String, detail: String) {
        iconView.isHidden = true
        valueLabel.isHidden = false
        detailLabel.isHidden = false
        secondaryDetailLabel.isHidden = false
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .regular)
        valueLabel.stringValue = title
        detailLabel.stringValue = subtitle
        secondaryDetailLabel.stringValue = detail
    }

    private func format(minutes: Int?) -> String {
        guard let minutes = minutes else { return "--" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h\(remainder)m" : "\(remainder)m"
    }

    private func formatPower() -> (title: String, detail: String) {
        guard let amperage = powerStatus.amperageMilliamps,
              let voltage = powerStatus.voltageMillivolts else {
            return ("POWER", "--")
        }
        let watts = abs(Double(amperage) * Double(voltage)) / 1_000_000
        let title = amperage > 0 || powerStatus.isConnected ? "CHG" : "USE"
        return (title, String(format: "%.1f W", watts))
    }

    private func updateIcon(value: Int) {
        if shouldShowBatteryIcon {
            let iconName: NSImage.Name
            if powerStatus.isCharged {
                iconView.subviews.forEach({ $0.removeFromSuperview() })
                iconName = "powerIsCharged"
            } else if powerStatus.isConnected {
                iconView.subviews.forEach({ $0.removeFromSuperview() })
                iconName = "powerIsCharging"
            } else {
                iconName = "powerEmpty"
                buildBatteryIcon(withValue: value)
            }
            iconView.image = Bundle(for: StatusWidget.self).image(forResource: iconName)
            iconView.isHidden = displayMode != .percentage
        } else {
            iconView.isHidden = true
            iconView.image = nil
            iconView.subviews.forEach({ $0.removeFromSuperview() })
        }
    }

    private func buildBatteryIcon(withValue value: Int) {
        let width = ((CGFloat(value) / 100) * (iconView.frame.width - 7))
        if !iconView.subviews.contains(bodyView) {
            iconView.addSubview(bodyView)
        }
        bodyView.layer?.backgroundColor = value <= 20 ? NSColor.red.cgColor : NSColor.white.cgColor
        bodyView.frame.size.width = max(width, 1.25)
    }
}
