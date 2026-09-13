import AppKit
import ApplicationServices

/// AXUIElement -> CGWindowID köprüsü. Genel API'de karşılığı yok; AltTab dahil
/// bütün pencere değiştiriciler bu özel sembolü kullanıyor.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ out: UnsafeMutablePointer<CGWindowID>) -> AXError

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let title: String
    let appName: String
    let bounds: CGRect
    var isMinimized: Bool = false
    /// Aynı uygulamanın kaçıncı penceresi (1 tabanlı) ve toplam sayısı.
    var indexInApp: Int = 1
    var countInApp: Int = 1

    var displayTitle: String { title.isEmpty ? appName : title }

    static func == (a: WindowInfo, b: WindowInfo) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

final class WindowStore {

    /// En son kullanılandan eskiye doğru pencere kimlikleri.
    private var mru: [CGWindowID] = []
    private var iconCache: [pid_t: NSImage] = [:]

    func icon(for pid: pid_t) -> NSImage? {
        if let cached = iconCache[pid] { return cached }
        let image = NSRunningApplication(processIdentifier: pid)?.icon
        if let image { iconCache[pid] = image }
        return image
    }

    func touch(_ id: CGWindowID) {
        mru.removeAll { $0 == id }
        mru.insert(id, at: 0)
        if mru.count > 200 { mru.removeLast(mru.count - 200) }
    }

    /// Hızlı yol: CGWindowList. Ekrandaki normal katman pencerelerini verir.
    func onScreenWindows() -> [WindowInfo] {
        let own = ProcessInfo.processInfo.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var result: [WindowInfo] = []
        for entry in raw {
            guard
                let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != own,
                let wid = entry[kCGWindowNumber as String] as? CGWindowID,
                let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                let rect = CGRect(dictionaryRepresentation: boundsDict)
            else { continue }

            if rect.width < Config.minWindowSize.width || rect.height < Config.minWindowSize.height {
                continue
            }
            let appName = entry[kCGWindowOwnerName as String] as? String ?? "?"
            if Config.ignoredApps.contains(appName) { continue }

            // Ekran kaydı izni yoksa başlık nil gelir; uygulama adına düşeriz.
            let title = entry[kCGWindowName as String] as? String ?? ""

            result.append(WindowInfo(id: wid, pid: pid, title: title,
                                     appName: appName, bounds: rect))
        }
        return result
    }

    /// Yavaş yol: küçültülmüş pencereleri AX üzerinden toplar.
    /// Yanıt vermeyen uygulamalarda AX çağrıları bloklayabildiği için ana iş
    /// parçacığında çağrılmamalı.
    func minimizedWindows() -> [WindowInfo] {
        var result: [WindowInfo] = []
        let own = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != own {
            let appName = app.localizedName ?? "?"
            if Config.ignoredApps.contains(appName) { continue }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { continue }

            for win in windows {
                var minimized: CFTypeRef?
                guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimized) == .success,
                      (minimized as? Bool) == true else { continue }

                var wid: CGWindowID = 0
                guard _AXUIElementGetWindow(win, &wid) == .success, wid != 0 else { continue }

                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String) ?? ""

                result.append(WindowInfo(id: wid, pid: app.processIdentifier, title: title,
                                         appName: appName, bounds: .zero, isMinimized: true))
            }
        }
        return result
    }

    /// MRU sırasına diz, aynı uygulamanın pencerelerini numaralandır.
    func ordered(_ windows: [WindowInfo]) -> [WindowInfo] {
        let rank = Dictionary(uniqueKeysWithValues: mru.enumerated().map { ($0.element, $0.offset) })
        var sorted = windows.sorted {
            (rank[$0.id] ?? Int.max) < (rank[$1.id] ?? Int.max)
        }

        var seen: [pid_t: Int] = [:]
        var totals: [pid_t: Int] = [:]
        for w in sorted { totals[w.pid, default: 0] += 1 }
        for i in sorted.indices {
            let pid = sorted[i].pid
            seen[pid, default: 0] += 1
            sorted[i].indexInApp = seen[pid]!
            sorted[i].countInApp = totals[pid]!
        }
        return sorted
    }

    /// Oturum başlarken çağrılan tam liste.
    @MainActor
    func snapshot(sameAppOnly: Bool) -> [WindowInfo] {
        var windows = onScreenWindows()

        if Settings.shared.includeMinimized {
            let known = Set(windows.map(\.id))
            windows += minimizedWindows().filter { !known.contains($0.id) }
        }

        if sameAppOnly, let front = NSWorkspace.shared.frontmostApplication {
            windows = windows.filter { $0.pid == front.processIdentifier }
        }
        return ordered(windows)
    }
}
