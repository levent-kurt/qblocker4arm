//
//  KeyListener.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 02/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

private func keyDownCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    // macOS disables a tap if its callback doesn't respond quickly enough.
    // Re-enable it immediately, otherwise CMD+Q silently stops being
    // intercepted at all until the app is relaunched.
    guard type != .tapDisabledByTimeout && type != .tapDisabledByUserInput else {
        if let keyDown = KeyListener.sharedKeyListener.keyDown {
            CGEvent.tapEnable(tap: keyDown, enable: true)
        }
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    // If the command key wasn't used we can pass the event on
    let flags = event.flags
    guard flags.contains(.maskCommand) else {
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    // If the shift key was held down we should ignore the event as it breaks the systemwide logout shortcut
    guard !flags.contains(.maskShift) else {
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    // If the q key wasn't clicked we can ignore the event too
    guard KeyListener.keyValueForEvent(event)?.lowercased() == "q" else {
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    guard KeyListener.sharedKeyListener.canQuit else {
        return nil
    }

    // get the current active app
    guard let app = NSWorkspace.shared.menuBarOwningApplication else {
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    // Check if the current app is in the list
    if let bundleId = app.bundleIdentifier {
        let isIdentifierListed = KeyListener.sharedKeyListener.listedBundleIdentifiers.contains(bundleId)
        if (ListMode.selectedMode == .blacklist && isIdentifierListed) || (ListMode.selectedMode == .whitelist && !isIdentifierListed) {
            return Unmanaged<CGEvent>.passUnretained(event)
        }
    }

    // Check that the app has CMD Q enabled. This is answered from a cache
    // kept warm in the background (see KeyListener.cachedCmdQActive) rather
    // than walking the app's AX menu tree synchronously here — that walk can
    // be slow enough against some apps (Chromium/Electron-based ones
    // especially) to blow past CGEventTap's response-time budget, which gets
    // the whole tap disabled and lets that keystroke straight through
    // unblocked.
    guard KeyListener.sharedKeyListener.cachedCmdQActive(for: app) else {
        return nil
    }

    // Showing the HUD is real window-server work (window creation, layout);
    // doing it synchronously here risks the same tap-disabling timeout as
    // the AX lookups above. Dispatch it off instead.
    if KeyListener.sharedKeyListener.canQuit && KeyListener.sharedKeyListener.tries <= KeyListener.delay {
        DispatchQueue.main.async {
            HUDAlert.sharedHUDAlert.showHUD(1)
        }
    }

    KeyListener.sharedKeyListener.tries += 1
    if KeyListener.sharedKeyListener.tries > KeyListener.delay {
        KeyListener.sharedKeyListener.tries = 0
        KeyListener.sharedKeyListener.canQuit = false
        DispatchQueue.main.async {
            HUDAlert.sharedHUDAlert.dismissHUD(false)
        }
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    return nil
}

private func keyUpCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    guard type != .tapDisabledByTimeout && type != .tapDisabledByUserInput else {
        if let keyUp = KeyListener.sharedKeyListener.keyUp {
            CGEvent.tapEnable(tap: keyUp, enable: true)
        }
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    // If the command key wasn't used we can pass the event on
    let flags = event.flags
    guard flags.contains(.maskCommand) else {
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    // If the shift key was held down we should ignore the event as it breaks the systemwide logout shortcut
    guard !flags.contains(.maskShift) else {
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    // If the q key wasn't clicked we can ignore the event too
    guard KeyListener.keyValueForEvent(event)?.lowercased() == "q" else {
        return Unmanaged<CGEvent>.passUnretained(event)
    }

    if KeyListener.sharedKeyListener.tries <= KeyListener.delay {
        KeyListener.sharedKeyListener.logAccidentalQuit()
    } else {
        DispatchQueue.main.async {
            HUDAlert.sharedHUDAlert.dismissHUD()
        }
    }

    KeyListener.sharedKeyListener.tries = 0
    KeyListener.sharedKeyListener.canQuit = true

    return Unmanaged<CGEvent>.passUnretained(event)
}


class KeyListener {

    /// Shared instance of the key listener
    static let sharedKeyListener = KeyListener()

    /// How long the Q key needs to be held before you can quit
    static var delay: Int {
        return UserDefaults.standard.integer(forKey: "delay")
    }

    /// The CGEvent for key down
    var keyDown: CFMachPort?

    /// The run loop for key down
    var keyDownRunLoopSource: CFRunLoopSource?

    /// The CG event for key up
    var keyUp: CFMachPort?

    /// The run loop for key up
    var keyUpRunLoopSource: CFRunLoopSource?

    /// The number of "tries" that CMD + Q have been hit.
    /// This is set when a user holds down the CMD + Q shortcut.
    var tries = 0

    /// Can quit is marked as false as soon as an app has just quit.
    /// If this is not checked then subsequent apps will continue to quit behind it.
    var canQuit = true

    /// The number of accidental quits that have been saved by QBlocker4arm
    var accidentalQuits: Int {
        return UserDefaults.standard.integer(forKey: "accidentalQuits")
    }

    /// Array of apps to be ignored/allowed (depending on the setting) by QBlocker4arm
    var list: [App]? {
        return ExcludedAppsStore.load().sorted { $0.name < $1.name }
    }

    /// The bundle identifiers of all apps from list
    var listedBundleIdentifiers: Set<String> {
        guard let apps = list else {
            return []
        }

        return Set(apps.map { $0.bundleID })
    }

    /// Cached "does this app have CMD+Q wired to quit" results, keyed by
    /// bundle identifier, kept warm in the background as the frontmost app
    /// changes so the event tap callback never has to do this synchronously.
    private var cmdQCache: [String: Bool] = [:]
    private let cmdQQueue = DispatchQueue(label: "com.leventkurt.app.QBlocker4arm.cmdQCheck")
    private var frontmostAppObserver: NSObjectProtocol?

    /**
     Start the keyDown and keyUp listeners.

     - throws: `KeyListenerError`
     */
    func start() throws {

        keyDown = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                                     callback: keyDownCallback,
                                     userInfo: nil)

        keyUp = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                   place: .headInsertEventTap,
                                   options: .defaultTap,
                                   eventsOfInterest: CGEventMask(1 << CGEventType.keyUp.rawValue),
                                   callback: keyUpCallback,
                                   userInfo: nil)

        guard let keyDown = keyDown else {
            throw KeyListenerError.accessibilityPermissionDenied
        }

        keyDownRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyDown, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), keyDownRunLoopSource, .commonModes)

        if let keyUp = keyUp {
            keyUpRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyUp, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), keyUpRunLoopSource, .commonModes)
        }

        frontmostAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self?.warmCmdQCache(for: app)
        }

        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            warmCmdQCache(for: frontmostApp)
        }

    }

    /**
     Look up (or, if not yet cached, kick off a background compute for and
     default to trusting) whether CMD+Q is wired to quit for the given app.

     - parameter app: The app to check

     - returns: Whether CMD+Q should be treated as active for this app
     */
    func cachedCmdQActive(for app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else {
            return true
        }

        if let cached = cmdQCache[bundleId] {
            return cached
        }

        // Not cached yet — warm it for next time, and default to "protected"
        // in the meantime rather than risk a synchronous AX call here.
        warmCmdQCache(for: app)
        return true
    }

    private func warmCmdQCache(for app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else {
            return
        }

        cmdQQueue.async { [weak self] in
            let active = KeyListener.cmdQActiveForApp(app)
            DispatchQueue.main.async {
                self?.cmdQCache[bundleId] = active
            }
        }
    }

    /**
     Store accidental quits in the user defaults
     */
    func logAccidentalQuit() {
        let quits = accidentalQuits + 1
        UserDefaults.standard.set(quits, forKey: "accidentalQuits")
    }

    /**
     Checks if CMD+Q is in the menu bar for the current application

     - parameter app: The Current App
     */
    class func cmdQActiveForApp(_ app: NSRunningApplication) -> Bool {

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var menuBar: AnyObject?
        AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBar)

        // If we can't get the menubar then exit
        guard let menuBar = menuBar else {
            return false
        }

        // Get the toplevel menu items
        let menu = menuBar as! AXUIElement
        var children: AnyObject?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &children)

        guard let items = children as? NSArray, items.count > 1 else {
            return false
        }

        // Get the submenus of the first item
        var subMenus: AnyObject?
        let title = items[1] as! AXUIElement // subscript 0 is the apple menu
        AXUIElementCopyAttributeValue(title, kAXChildrenAttribute as CFString, &subMenus)

        guard let menus = subMenus as? NSArray, menus.count > 0 else {
            return false
        }

        // Get the entries of the submenu
        var entries: AnyObject?
        let submenu = menus[0] as! AXUIElement
        AXUIElementCopyAttributeValue(submenu, kAXChildrenAttribute as CFString, &entries)

        guard let menuItems = entries as? NSArray, menuItems.count > 0 else {
            return false
        }

        // Loop through the menu items and check if CMD + Q is the shortcut
        for item in menuItems {
            var cmdChar: AnyObject?
            AXUIElementCopyAttributeValue(item as! AXUIElement, kAXMenuItemCmdCharAttribute as CFString, &cmdChar)
            if let char = cmdChar as? String, char == "Q" {
                return true
            }
        }

        return false
    }

    /**
     Return the key character

     - parameter event: They keyboard event

     - returns: The characters clicked
     */
    class func keyValueForEvent(_ event: CGEvent) -> String? {
        return NSEvent(cgEvent: event)?.charactersIgnoringModifiers
    }

}
