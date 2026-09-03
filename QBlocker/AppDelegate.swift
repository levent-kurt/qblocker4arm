//
//  AppDelegate.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 01/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var permissionsWindowController: PermissionsWindowController?
    private var firstRunWindowController: NSWindowController?
    private lazy var preferencesWindowController: NSWindowController = {
        return NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "preferences window") as! NSWindowController
    }()

    class var sharedDelegate: AppDelegate? {
        return NSApplication.shared.delegate as? AppDelegate
    }

    // MARK: - Instantiation

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [
            "accidentalQuits": 0,
            "firstRunComplete": false,
            "listMode": 0,
            "delay": 4
        ])
    }

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        relocateToApplicationsFolderIfNeeded()
        checkPermissionsAndStart()
    }

    // MARK: - Actions

    /**
     Show the first run screen if the NSUserDefault stating it has already be run isn't set
     */
    func showFirstRunWindowIfRequired() {
        guard !UserDefaults.standard.bool(forKey: "firstRunComplete") else {
            return
        }

        if let windowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "first run window") as? NSWindowController {
            firstRunWindowController = windowController
            NSApp.activate(ignoringOtherApps: true)
            firstRunWindowController?.showWindow(self)
            firstRunWindowController?.window?.makeKeyAndOrderFront(self)

            UserDefaults.standard.set(true, forKey: "firstRunComplete")
        }
    }

    /**
     Bring the app into foreground and show the preferences window
     */
    func showPreferencesWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.preferencesWindowController.showWindow(nil)
    }

    // MARK: - Permissions

    /**
     Check whether both Accessibility and Input Monitoring are granted.
     Both are required — Accessibility to read a frontmost app's menu bar,
     Input Monitoring (a separate permission since macOS Catalina) to
     actually create a system-wide keyboard event tap. Missing either one
     leaves the tap silently non-functional with no error.

     CGRequestListenEventAccess() is what registers the app with Input
     Monitoring so it actually appears in System Settings at all. It's safe
     to call every launch as long as it's skipped once already granted
     (CGPreflightListenEventAccess() is checked first) — that avoids
     re-prompting a user who already said yes, while still registering (and
     re-registering, if a stale/deleted TCC entry left the app invisible in
     Settings) on every launch until it's actually granted.
     */
    private func checkPermissionsAndStart() {
        let promptFlag = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options: CFDictionary = [promptFlag: false] as CFDictionary
        let accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        let inputMonitoringTrusted = requestOrPreflightInputMonitoring()

        guard accessibilityTrusted && inputMonitoringTrusted else {
            NSApp.activate(ignoringOtherApps: true)
            let windowController = PermissionsWindowController.make { [weak self] in
                self?.permissionsWindowController?.close()
                self?.permissionsWindowController = nil
                self?.startAfterPermissionsGranted()
            }
            permissionsWindowController = windowController
            windowController.showWindow(self)
            windowController.window?.makeKeyAndOrderFront(self)
            return
        }

        startAfterPermissionsGranted()
    }

    private func requestOrPreflightInputMonitoring() -> Bool {
        if CGPreflightListenEventAccess() {
            return true
        }
        return CGRequestListenEventAccess()
    }

    private func startAfterPermissionsGranted() {
        do {
            try KeyListener.sharedKeyListener.start()
        } catch {
            NSLog("Could not launch listener")
        }

        // HUDAlert's window/storyboard scene loads lazily on first access.
        // Force that now, off the CMD+Q hot path, so the first real quit
        // attempt isn't the one paying for that (occasionally multi-second,
        // especially on a cold disk cache right after a reboot) load.
        DispatchQueue.main.async {
            _ = HUDAlert.sharedHUDAlert
        }

        showFirstRunWindowIfRequired()
    }

    // MARK: - Relocation

    /**
     If the app isn't running from /Applications, offer to move it there and
     relaunch. Running an app straight out of Downloads (or a mounted DMG)
     leaves it subject to macOS's App Translocation, which runs it from a
     randomized, read-only path and would break the login item registration
     and the persisted excluded-apps file's location across launches.
     */
    private func relocateToApplicationsFolderIfNeeded() {
        let bundlePath = Bundle.main.bundlePath
        guard !bundlePath.hasPrefix("/Applications/") else {
            return
        }

        let destinationPath = "/Applications/" + (bundlePath as NSString).lastPathComponent

        let alert = NSAlert()
        alert.messageText = "Move to Applications folder?"
        alert.informativeText = "\(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "This app") works best when run from your Applications folder. Move it there now?"
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            try fileManager.copyItem(atPath: bundlePath, toPath: destinationPath)
        } catch {
            NSLog("Could not move app to Applications: \(error)")
            return
        }

        // Trash (not permanently delete) the original now that the copy in
        // /Applications is in place, so this behaves like an actual move.
        try? fileManager.trashItem(at: URL(fileURLWithPath: bundlePath), resultingItemURL: nil)

        // Reveal the moved copy and quit, rather than auto-relaunching from
        // the new location — jumping straight into another window (like the
        // permissions checklist) right after this alert is confusing; it's
        // clearer as two distinct steps: move, then the user opens it.
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: destinationPath)])
        NSApp.terminate(self)
    }

}
