import AppKit
import ApplicationServices

enum DesktopResult: String { case empty, icon, otherWindow, unknown, permissionNeeded }

/// Fail closed: only an accessible Finder desktop background is accepted.
/// No screen capture, keyboard monitoring, content reading or event suppression.
final class DesktopDetector {
    var hasPermission: Bool { AXIsProcessTrusted() }
    private let system = AXUIElementCreateSystemWide()

    func classify(_ point: NSPoint, ownPID: pid_t) -> DesktopResult {
        guard hasPermission else { return .permissionNeeded }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cgPoint = CGPoint(x:point.x,y:primaryHeight-point.y)
        guard let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] else { return .unknown }
        // Reject real windows/menus at this location before querying the desktop.
        // Window titles are intentionally never read or logged.
        for window in windowInfo {
            guard let pid = window[kCGWindowOwnerPID as String] as? Int,
                  pid != ownPID,
                  let bounds = window[kCGWindowBounds as String] as? [String:Any],
                  let rect = CGRect(dictionaryRepresentation:bounds as CFDictionary), rect.contains(cgPoint),
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0.01 else { continue }
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            if layer >= 0 { return .otherWindow }
        }
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.finder").first else { return .unknown }
        let finderAX = AXUIElementCreateApplication(finder.processIdentifier)
        AXUIElementSetMessagingTimeout(finderAX,0.15)
        var hit: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(finderAX,Float(cgPoint.x),Float(cgPoint.y),&hit)
        guard result == .success, let element = hit else { return .unknown }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element,&pid) == .success, pid == finder.processIdentifier else { return .unknown }
        let role = string(element,kAXRoleAttribute)
        // Desktop icons may expose image, button or static-text descendants.
        if ["AXImage","AXButton","AXStaticText","AXTextField","AXCell","AXRow"].contains(role) { return .icon }
        guard ["AXScrollArea","AXList","AXGroup","AXLayoutArea","AXBrowser"].contains(role) else { return .unknown }
        // Finder windows are already rejected by the window hit test. Only accept
        // background containers with no represented URL (items expose AXURL).
        var url: CFTypeRef?
        if AXUIElementCopyAttributeValue(element,kAXURLAttribute as CFString,&url) == .success, url != nil { return .icon }
        return .empty
    }
    private func string(_ element: AXUIElement,_ name: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,name as CFString,&value) == .success else { return "" }
        return value as? String ?? ""
    }
}

final class DesktopMonitor {
    var onClick: ((NSPoint) -> Void)?
    var onClassification: ((DesktopResult) -> Void)?
    let detector = DesktopDetector()
    private var down: (NSPoint,Double,DesktopResult)?
    private var monitor: Any?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.leftMouseUp,.leftMouseDragged]) { [weak self] event in
            guard let self else { return }
            let point = NSEvent.mouseLocation
            if event.type == .leftMouseDown {
                let classification = self.detector.classify(point,ownPID:self.ownPID)
                self.down = (point,event.timestamp,classification)
                self.onClassification?(classification)
            } else if event.type == .leftMouseDragged {
                if let start = self.down, hypot(point.x-start.0.x,point.y-start.0.y) > 6 { self.down = nil }
            } else {
                defer { self.down = nil }
                guard let start = self.down, start.2 == .empty,
                      event.timestamp-start.1 < 0.6,
                      hypot(point.x-start.0.x,point.y-start.0.y) <= 6 else { return }
                self.onClick?(point)
            }
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; down = nil }
    deinit { stop() }
}
