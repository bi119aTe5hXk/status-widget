//
//  SSystemItem.swift
//  Status
//

import Foundation
import Cocoa
import Darwin

internal class SSystemItem: StatusItem {
    private var refreshTimer: Timer?
    private var previousCPUInfo: [integer_t]?

    private let fixedImageWidth = CGFloat(58)
    private let imageView: NSImageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 58, height: 26))

    var enabled: Bool { return Preferences[.shouldShowSystemItem] }
    var title: String { return "system" }
    var view: NSView { return imageView }

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
        let cpuText = "CPU \(Int(round(cpuUsagePercent())))%"
        let memoryText = String(format: "MEM %.1fG", usedMemoryGB())
        let menuBarImage = createMenuBarImage(upper: cpuText, lower: memoryText)

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

    private func cpuUsagePercent() -> Double {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &cpuInfo, &cpuInfoCount)
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return 0 }

        let currentCPUInfo = Array(UnsafeBufferPointer(start: cpuInfo, count: Int(cpuInfoCount)))
        let byteCount = vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), byteCount)

        defer { previousCPUInfo = currentCPUInfo }
        guard let previousCPUInfo = previousCPUInfo, previousCPUInfo.count == currentCPUInfo.count else {
            return 0
        }

        var totalTicks: UInt64 = 0
        var usedTicks: UInt64 = 0
        let stateCount = Int(CPU_STATE_MAX)

        for cpuIndex in 0..<Int(processorCount) {
            let offset = cpuIndex * stateCount
            let user = tickDelta(currentCPUInfo, previousCPUInfo, offset + Int(CPU_STATE_USER))
            let system = tickDelta(currentCPUInfo, previousCPUInfo, offset + Int(CPU_STATE_SYSTEM))
            let nice = tickDelta(currentCPUInfo, previousCPUInfo, offset + Int(CPU_STATE_NICE))
            let idle = tickDelta(currentCPUInfo, previousCPUInfo, offset + Int(CPU_STATE_IDLE))

            usedTicks += user + system + nice
            totalTicks += user + system + nice + idle
        }

        guard totalTicks > 0 else { return 0 }
        return min(100, max(0, Double(usedTicks) / Double(totalTicks) * 100))
    }

    private func tickDelta(_ current: [integer_t], _ previous: [integer_t], _ index: Int) -> UInt64 {
        guard index < current.count, index < previous.count else { return 0 }
        let currentValue = Int64(current[index])
        let previousValue = Int64(previous[index])
        return UInt64(max(0, currentValue - previousValue))
    }

    private func usedMemoryGB() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        let usedPages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        let usedBytes = usedPages * UInt64(pageSize)
        return Double(usedBytes) / 1024 / 1024 / 1024
    }

    private func createAttributedString(value: String, color: NSColor) -> NSAttributedString {
        let attrString = NSMutableAttributedString(string: value)
        let font = NSFont.systemFont(ofSize: 9)
        attrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: attrString.length))
        attrString.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: attrString.length))
        return attrString
    }

    private func createMenuBarImage(upper: String, lower: String) -> NSImage? {
        let upperStrAttr = createAttributedString(value: upper, color: NSColor.white)
        let lowerStrAttr = createAttributedString(value: lower, color: NSColor.white)
        let textWidth = fixedImageWidth
        let menuBarImage = NSImage(size: NSSize(width: textWidth, height: CGFloat(20.0)))

        menuBarImage.lockFocus()

        let upperStringSize = upperStrAttr.size()
        upperStrAttr.draw(at: NSPoint(x: textWidth - upperStringSize.width, y: menuBarImage.size.height - 9))

        let lowerStringSize = lowerStrAttr.size()
        lowerStrAttr.draw(at: NSPoint(x: textWidth - lowerStringSize.width, y: -1))

        menuBarImage.unlockFocus()
        return menuBarImage
    }
}
