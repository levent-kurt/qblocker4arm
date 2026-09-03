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

     Calling CGRequestListenEventAccess() here (rather than just
     preflighting) registers the app with Input Monitoring so it actually
     appears in System Settings — without this call it may never show up
     there at all.
     */
    private func checkPermissionsAndStart() {
        let promptFlag = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options: CFDictionary = [promptFlag: false] as CFDictionary
        let accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        let inputMonitoringTrusted = CGRequestListenEventAccess()

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

    private func startAfterPermissionsGranted() {
        do {
            try KeyListener.sharedKeyListener.start()
        } catch {
            NSLog("Could not launch listener")
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

        NSWorkspace.shared.open(URL(fileURLWithPath: destinationPath))
        NSApp.terminate(self)
    }

}
