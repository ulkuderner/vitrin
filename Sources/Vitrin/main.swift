import AppKit

// Menü çubuğu uygulaması: Dock'ta görünmez, pencere açmaz.
// Üst seviye kod ana iş parçacığında çalışır ama Swift 5 kipinde MainActor
// izolasyonuna sahip değildir; @MainActor olan AppDelegate'i kurmak için
// izolasyonu açıkça beyan ediyoruz.
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
