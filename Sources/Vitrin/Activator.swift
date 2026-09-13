// Vitrin — macOS window-level switcher
// Copyright (C) 2026 Çağlar Ülküderner
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. See <https://www.gnu.org/licenses/> for details.
//
// https://github.com/ulkuderner/vitrin

import AppKit
import ApplicationServices

enum Activator {

    /// pid altındaki AX pencerelerinden CGWindowID'si eşleşeni bulur.
    private static func axWindow(pid: pid_t, id: CGWindowID) -> (AXUIElement, AXUIElement)? {
        let axApp = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }

        for win in windows {
            var wid: CGWindowID = 0
            if _AXUIElementGetWindow(win, &wid) == .success, wid == id {
                return (axApp, win)
            }
        }
        return nil
    }

    /// Pencereyi öne getir, gerekirse simge durumundan çıkar, uygulamayı etkinleştir.
    static func focus(_ info: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: info.pid) else { return }

        if let (axApp, win) = axWindow(pid: info.pid, id: info.id) {
            var minimized: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimized) == .success,
               (minimized as? Bool) == true {
                AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            AXUIElementPerformAction(win, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, win)
        }

        app.activate()
    }

    static func close(_ info: WindowInfo) {
        guard let (_, win) = axWindow(pid: info.pid, id: info.id) else { return }
        var button: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXCloseButtonAttribute as CFString, &button) == .success,
           let button = button {
            AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
        }
    }

    static func minimize(_ info: WindowInfo) {
        guard let (_, win) = axWindow(pid: info.pid, id: info.id) else { return }
        AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    static func quitApp(_ info: WindowInfo) {
        NSRunningApplication(processIdentifier: info.pid)?.terminate()
    }
}