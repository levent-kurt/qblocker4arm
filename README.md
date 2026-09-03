![QBlocker Icon](https://raw.githubusercontent.com/steve228uk/QBlocker/master/Assets/qblocker-icons/github.png)

# QBlocker4arm

QBlocker4arm stops you from accidentally quitting an app when you actually meant to close the window. It works by blocking the default CMD + Q keyboard shortcut and forcing you to hold it down to quit.

This is an Apple Silicon (arm64) port of [Stephen Radford](https://github.com/steve228uk)'s original [QBlocker](https://github.com/steve228uk/QBlocker) — all credit for the idea, design, and original implementation goes to him. Huge thanks for building and open-sourcing it in the first place.

## Why this fork exists

Apple has [confirmed that macOS 27 will be the final release to support Rosetta](https://developer.apple.com/news/?id=w5ngl9k2), the compatibility layer that lets Intel-only apps run on Apple Silicon Macs — after that, Intel-only apps stop working entirely. Starting with macOS 26.4, the system already warns you when launching an app that relies on Rosetta.

QBlocker's original 2016 codebase (Swift 2, CocoaPods, and dependencies that predate Apple Silicon by years) couldn't be recompiled as-is on modern Xcode, so this fork is a full port to a native, dependency-free, arm64-only build.

## What changed from the original

- Migrated the entire codebase from Swift 2 to modern Swift 5
- Removed all third-party dependencies (DevMateKit, RealmSwift, SRTabBarController) — the app is now pure AppKit/Foundation
  - Analytics/auto-update (DevMateKit, long since discontinued) removed entirely
  - Excluded-apps storage moved from Realm to a small `Codable`/JSON store
  - The custom tab bar UI replaced with AppKit's native `NSTabViewController`
- Dropped CocoaPods in favor of no dependency manager at all
- Replaced the legacy, now crash-prone `LSSharedFileList` Login Items API with the modern `SMAppService`
- Fixed the "Open System Preferences" flow for the current System Settings app (the old AppleScript pane-reveal approach no longer works)
- Project now builds `arm64` only, targeting macOS 13+

## Download

Grab the latest build from the [Releases page](https://github.com/levent-kurt/qblocker4arm/releases).

Since this build isn't notarized, macOS Gatekeeper will flag it on first launch — right-click (or Control-click) the app and choose **Open** to run it anyway.

## Contributing

Any contribution is welcome whether it's reporting bugs, helping with design, fixing typos or getting stuck in with development.

## Screenshots

### Menu Bar Icon + Menu

![QBlocker Menu](http://i.imgur.com/DqbWTXN.png)

### Quit Message Demonstration

![Quitting](http://i.imgur.com/GDRx911.png)

### Preferences

![Preferences](https://raw.githubusercontent.com/steve228uk/QBlocker/master/Assets/screenshots/preferences.png)

## I love QBlocker, can I donate?

Neither the original author nor this fork accepts donations — instead please consider donating to one of the following charities:

- **[Stonewall](http://www.stonewall.org.uk/support-stonewall)**
- **[Shelter](http://www.shelter.org.uk)**
- **[Epilepsy Action](https://www.epilepsy.org.uk/involved/donations)**
- **[UNICEF](http://www.unicef.org.uk)**
