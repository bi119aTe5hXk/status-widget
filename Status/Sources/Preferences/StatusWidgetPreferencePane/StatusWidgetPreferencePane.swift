//
//  StatusWidgetPreferencePane.swift
//  Pock
//
//  Created by Pierluigi Galdi on 30/03/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Cocoa
import PockKit
import Defaults

class StatusWidgetPreferencePane: NSViewController, NSTextFieldDelegate, PKWidgetPreference {
    
    static var nibName: NSNib.Name = "StatusWidgetPreferencePane"

    /// UI
	@IBOutlet weak var showLangItem:			  NSButton!
    @IBOutlet weak var showWifiItem:              NSButton!
    @IBOutlet weak var showNetowrkItem:           NSButton!
    @IBOutlet weak var showSystemItem:            NSButton!
    @IBOutlet weak var showTempFanItem:           NSButton!
    @IBOutlet weak var showPowerItem:             NSButton!
    @IBOutlet weak var showBatteryIconItem:       NSButton!
    @IBOutlet weak var showBatteryPercentageItem: NSButton!
    @IBOutlet weak var showDateItem:              NSButton!
    @IBOutlet weak var timeFormatTextField:       NSTextField!

    private weak var itemStackView: NSStackView?
    private var orderRows: [PrimaryStatusItem: NSStackView] = [:]
    private var orderButtons: [PrimaryStatusItem: (up: NSButton, down: NSButton)] = [:]
    private var firstOrderRowIndex = 0
    
    func reset() {
        Preferences.reset()
        loadCheckboxState()
        applyOrderRows()
        NotificationCenter.default.post(name: .shouldReloadStatusWidget, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.superview?.wantsLayer = true
        self.view.wantsLayer = true
        self.loadCheckboxState()
        self.timeFormatTextField.delegate = self
        self.timeFormatTextField.stringValue = Preferences[.timeFormatTextField]
        configureOrderControls()
    }

    private func configureOrderControls() {
        guard let stackView = showNetowrkItem.superview as? NSStackView else { return }
        itemStackView = stackView

        let itemButtons: [PrimaryStatusItem: NSButton] = [
            .network: showNetowrkItem,
            .system: showSystemItem,
            .temperatureFan: showTempFanItem,
            .power: showPowerItem
        ]
        firstOrderRowIndex = itemButtons.values.compactMap({
            stackView.arrangedSubviews.firstIndex(of: $0)
        }).min() ?? 0

        for identifier in PrimaryStatusItem.allCases {
            guard let checkbox = itemButtons[identifier] else { continue }
            stackView.removeArrangedSubview(checkbox)
            checkbox.removeFromSuperview()

            let spacer = NSView(frame: .zero)
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let up = orderButton(title: "▲", tag: identifier.orderTag)
            let down = orderButton(title: "▼", tag: identifier.orderTag + 100)
            let row = NSStackView(views: [checkbox, spacer, up, down])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 3
            orderRows[identifier] = row
            orderButtons[identifier] = (up, down)
        }
        applyOrderRows()
    }

    private func orderButton(title: String, tag: Int) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(movePrimaryItem(_:)))
        button.tag = tag
        button.bezelStyle = .texturedRounded
        button.font = NSFont.systemFont(ofSize: 9)
        button.toolTip = title == "▲" ? "Move item left" : "Move item right"
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        return button
    }

    private func applyOrderRows() {
        guard let stackView = itemStackView else { return }
        for row in orderRows.values {
            if stackView.arrangedSubviews.contains(row) {
                stackView.removeArrangedSubview(row)
                row.removeFromSuperview()
            }
        }
        for (offset, identifier) in Preferences.primaryItemOrder.enumerated() {
            guard let row = orderRows[identifier] else { continue }
            stackView.insertArrangedSubview(row, at: firstOrderRowIndex + offset)
            orderButtons[identifier]?.up.isEnabled = offset > 0
            orderButtons[identifier]?.down.isEnabled = offset < Preferences.primaryItemOrder.count - 1
        }
    }

    @objc private func movePrimaryItem(_ sender: NSButton) {
        let movingDown = sender.tag >= 100
        let rawTag = movingDown ? sender.tag - 100 : sender.tag
        guard let identifier = PrimaryStatusItem.allCases.first(where: { $0.orderTag == rawTag }) else { return }
        var order = Preferences.primaryItemOrder
        guard let index = order.firstIndex(of: identifier) else { return }
        let destination = index + (movingDown ? 1 : -1)
        guard order.indices.contains(destination) else { return }
        order.swapAt(index, destination)
        Preferences.primaryItemOrder = order
        applyOrderRows()
        NotificationCenter.default.post(name: .shouldReloadStatusWidget, object: nil)
    }
    
    private func loadCheckboxState() {
		self.showLangItem.state              = Preferences[.shouldShowLangItem]          ? .on : .off
		self.showWifiItem.state              = Preferences[.shouldShowWifiItem]          ? .on : .off
        self.showNetowrkItem.state           = Preferences[.shouldShowNetworkItem]       ? .on : .off
        self.showSystemItem.state            = Preferences[.shouldShowSystemItem]        ? .on : .off
        self.showTempFanItem.state           = Preferences[.shouldShowTempFanItem]       ? .on : .off
        self.showPowerItem.state             = Preferences[.shouldShowPowerItem]         ? .on : .off
        self.showBatteryIconItem.state       = Preferences[.shouldShowBatteryIcon]       ? .on : .off
        self.showBatteryPercentageItem.state = Preferences[.shouldShowBatteryPercentage] ? .on : .off
        self.showDateItem.state              = Preferences[.shouldShowDateItem]          ? .on : .off
    }
    
    @IBAction func didChangeCheckboxValue(_ checkbox: NSButton) {
		var key: Preferences.Keys
        switch checkbox.tag {
		case 0:
			key = .shouldShowLangItem
        case 1:
            key = .shouldShowWifiItem
        case 2:
            key = .shouldShowPowerItem
        case 31:
            key = .shouldShowBatteryIcon
        case 32:
            key = .shouldShowBatteryPercentage
        case 4:
            key = .shouldShowDateItem
        case 5:
            key = .shouldShowNetworkItem
        case 6:
            key = .shouldShowTempFanItem
        case 7:
            key = .shouldShowSystemItem
        default:
            return
        }
		Preferences[key] = checkbox.state == .on
		NotificationCenter.default.post(name: .shouldReloadStatusWidget, object: nil)
    }
    
    @IBAction func openTimeFormatHelpURL(_ sender: NSButton) {
        guard let url = URL(string: "https://www.mowglii.com/itsycal/datetime.html") else { return }
        NSWorkspace.shared.open(url)
    }
    
    func controlTextDidChange(_ obj: Notification) {
		Preferences[.timeFormatTextField] = timeFormatTextField.stringValue
    }
}

private extension PrimaryStatusItem {
    var orderTag: Int {
        return PrimaryStatusItem.allCases.firstIndex(of: self) ?? 0
    }
}
