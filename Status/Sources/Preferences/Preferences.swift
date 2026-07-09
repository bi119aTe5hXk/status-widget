//
//  Preferences.swift
//  Status
//
//  Created by Pierluigi Galdi on 18/01/2020.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import Foundation

extension NSNotification.Name {
    static let shouldReloadStatusWidget = NSNotification.Name("shouldReloadStatusWidget")
}

internal enum PrimaryStatusItem: String, CaseIterable {
    case network
    case system
    case temperatureFan
    case power
}

internal struct Preferences {
    internal enum Keys: String {
        case shouldShowLangItem
        case shouldShowWifiItem
        case shouldShowNetworkItem
        case shouldShowTempFanItem
        case shouldShowSystemItem
        case shouldShowPowerItem
        case shouldShowBatteryIcon
        case shouldShowBatteryPercentage
        case shouldShowDateItem
        case primaryItemOrder
        case timeFormatTextField
    }
    static subscript<T>(_ key: Keys) -> T {
        get {
            guard let value = UserDefaults.standard.value(forKey: key.rawValue) as? T else {
                switch key {
                case .shouldShowLangItem:
                    return false as! T
                case .shouldShowWifiItem:
                    return true as! T
                case .shouldShowNetworkItem:
                    return true as! T
                case .shouldShowTempFanItem:
                    return true as! T
                case .shouldShowSystemItem:
                    return true as! T
                case .shouldShowPowerItem:
                    return true as! T
                case .shouldShowBatteryIcon:
                    return true as! T
                case .shouldShowBatteryPercentage:
                    return false as! T
                case .shouldShowDateItem:
                    return true as! T
                case .primaryItemOrder:
                    return PrimaryStatusItem.allCases.map({ $0.rawValue }) as! T
                case .timeFormatTextField:
                    return "EE dd MMM HH:mm" as! T
                }
            }
            return value
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: key.rawValue)
        }
    }

    static var primaryItemOrder: [PrimaryStatusItem] {
        get {
            let stored: [String] = Preferences[.primaryItemOrder]
            let valid = stored.compactMap(PrimaryStatusItem.init(rawValue:))
            let missing = PrimaryStatusItem.allCases.filter({ !valid.contains($0) })
            return valid + missing
        }
        set {
            Preferences[.primaryItemOrder] = newValue.map({ $0.rawValue })
        }
    }

    static func reset() {
        Preferences[.shouldShowLangItem] = false
        Preferences[.shouldShowWifiItem] = true
        Preferences[.shouldShowNetworkItem] = true
        Preferences[.shouldShowTempFanItem] = true
        Preferences[.shouldShowSystemItem] = true
        Preferences[.shouldShowPowerItem] = true
        Preferences[.shouldShowBatteryIcon] = true
        Preferences[.shouldShowBatteryPercentage] = true
        Preferences[.shouldShowDateItem] = true
        Preferences.primaryItemOrder = PrimaryStatusItem.allCases
        Preferences[.timeFormatTextField] = "EE dd MMM HH:mm"
    }
}
