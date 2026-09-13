# Vitrin

A window-level switcher for macOS. It selects **windows, not apps**: several
windows of the same application are listed separately, each with its own live
preview.

Built as a dependency-free Swift package — `swift build` alone, no Xcode
project.

> **Not on the Mac App Store, and it cannot be.** Vitrin needs a session-level
> `CGEvent` tap to capture the shortcut and the Accessibility API to raise other
> apps' windows. Neither is possible inside the App Sandbox, and the app relies
> on `_AXUIElementGetWindow`, a private symbol with no public equivalent. Every
> comparable tool (AltTab, Contexts, rcmd) is distributed the same way: signed
> with Developer ID and notarised.

## Install

Download the notarised DMG from Releases, or build it yourself:

```bash
git clone https://github.com/ulkuderner/vitrin.git
cd vitrin
make install          # builds and installs to ~/Applications
open ~/Applications/Vitrin.app
```

Requires macOS 14 or later and the Xcode command line tools.

### Permissions

| Permission | Why |
|---|---|
| Accessibility | Capture the shortcut (CGEvent tap) and raise windows (AX) |
| Screen Recording | Window **titles** and live previews |

Without Screen Recording the app still works, but titles come back empty and
cards fall back to application icons.

## Shortcuts

| Key | Action |
|---|---|
| ⌘Tab | Cycle forward through all windows |
| ⌘⇧Tab | Cycle backward |
| ⌘` | Restrict to the frontmost app's windows |
| Arrow keys | Move within the grid |
| Release ⌘ | Switch to the selected window |
| W / M / Q | Close window / minimise / quit app |
| , | Open settings |
| Esc | Cancel |

The trigger key is configurable — ⌘ or ⌥. It defaults to ⌘ because on
PC-layout keyboards the physical Alt key usually sends Command, which is what
most people reaching for "Alt+Tab" actually press.

## Layouts

Grid, Filmstrip, Coverflow, Fan and Book. The four non-grid layouts share one
transform: each card's offset, rotation and scale are derived from its distance
to the selection, so transitions come for free and stay consistent.

## Design notes

**Motion adapts to input rate.** Consecutive selections under 220 ms switch to a
shorter spring and drop the stagger — the interface should never lag behind a
user hammering Tab. Springs are interruptible, so an in-flight animation carries
its velocity into the new target instead of restarting.

**Accessibility preferences are honoured.** Reduce Motion disables springs,
flight, sheen, parallax and the fold entrance. Reduce Transparency swaps
materials for solid colours without overriding the user's own transparency
setting. Increase Contrast thickens the selection border. All three are
observed live.

**Selection is light, not chrome.** No saturated ring: a hairline gradient edge,
a half-pixel specular rim, and a two-layer bloom whose colour is sampled from
the window's own dominant colour.

**Concentric radii.** Inner radius = outer radius − inset, everywhere.

## Architecture

```
main.swift            NSApplication setup (.accessory policy)
AppDelegate.swift     Menu bar, session flow, MRU tracking
HotkeyTap.swift       CGEvent tap; swallows Tab while the trigger is held
WindowStore.swift     CGWindowList (fast) + AX pass (minimised) + MRU
Capture.swift         Thumbnails via ScreenCaptureKit
Activator.swift       Raise, close, minimise through AX
SwitcherPanel.swift   Non-activating NSPanel + SwiftUI hosting
SwitcherView.swift    Grid and carousel layouts
Glass.swift           Material surfaces, specular sweep, dominant colour
ScrimWindow.swift     Full-screen dim and blur behind the switcher
FlightAnimator.swift  Thumbnail flight and arrival pulse
Motion.swift          Animation tokens, rate adaptation
Settings*.swift       Preferences model and window
L10n.swift            Localisation (12 languages)
```

Flow: the tap catches the keyDown and returns `nil` to swallow it, so macOS's
own switcher never appears. `WindowStore` reads layer-0 windows from
`CGWindowListCopyWindowInfo`, optionally adds minimised ones through the
Accessibility API, and orders by MRU. The panel appears immediately; thumbnails
are captured in parallel and fade in as they arrive. Releasing the trigger
produces a `flagsChanged` event, and `Activator.focus` raises the window with
`kAXRaiseAction` plus `NSRunningApplication.activate`.

## Known constraints

- **`_AXUIElementGetWindow` is private.** There is no public way to map an AX
  window element to a `CGWindowID`. This is the reason App Store distribution is
  impossible.
- **AX calls can block.** An unresponsive application can stall
  `AXUIElementCopyAttributeValue` for seconds. `minimizedWindows()` is currently
  synchronous; add `AXUIElementSetMessagingTimeout` before relying on it under
  load.
- **Event taps time out.** Heavy work inside the callback makes the system
  disable the tap; work is deferred to the next run loop pass and
  `tapDisabledByTimeout` is caught and re-enabled.
- **Stage Manager** changes how windows are presented, so `CGWindowList`
  reports fewer windows than expected.
- **Coordinate systems.** `CGWindowList` is top-left origin, Cocoa is
  bottom-left, and SwiftUI's `.global` frame is relative to the panel content.
  `FlightAnimator.cocoaRect(fromCG:)` and `selectedCellScreenFrame()` handle the
  conversions — check there first if the flight lands in the wrong place.

## Building and releasing

```bash
make              # build and relaunch (development)
make icon         # regenerate the app icon from code
make release      # signed universal DMG (Developer ID)
make notarize     # sign, notarise, staple
make check        # identities, signature, architectures, Gatekeeper
```

Local development signs with a self-signed `Vitrin Dev` identity so that TCC
permissions survive rebuilds — ad-hoc signatures change their cdhash on every
build, which silently invalidates the Accessibility grant.

Before the first notarisation:

```bash
make creds APPLE_ID="you@example.com" TEAM_ID="XXXXXXXXXX"
```

The password is read from the terminal with echo disabled and stored in the
keychain by `notarytool`. It is never written to a file.

## Credits

Design and development: Çağlar Ülküderner.

Architecture informed by `lwouis/alt-tab-macos` and `sergio-farfan/alttab-macos`.

## License

MIT
