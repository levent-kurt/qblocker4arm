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

    private var accessibilityWindowController: NSWindowController?
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
        checkAccessibilityTrust()
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

    // MARK: - Accessibility

    /**
     Check whether accessibility is trusted. Toggling accessibility for an
     already-running process in System Settings doesn't reliably update
     AXIsProcessTrustedWithOptions for that same process without a relaunch,
     so rather than polling indefinitely, the accessibility window asks the
     user to re-open the app once they've granted it.
     */
    private func checkAccessibilityTrust() {
        let promptFlag = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options: CFDictionary = [promptFlag: false] as CFDictionary

        guard AXIsProcessTrustedWithOptions(options) else {
            if let windowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "accessibility window") as? NSWindowController {
                accessibilityWindowController = windowController
                accessibilityWindowController?.showWindow(self)
                accessibilityWindowController?.window?.makeKeyAndOrderFront(self)
            }
            return
        }

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
