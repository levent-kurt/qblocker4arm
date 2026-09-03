//
//  ExcludeViewController.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 07/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

class ExcludeViewController: NSViewController {

    @IBOutlet weak var tableView: NSTableView!

    // MARK: - Actions

    @IBAction func addClicked(_ sender: AnyObject) {
        let panel = NSOpenPanel()
        panel.title = "Choose a .app"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["app"]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK {
                for url in panel.urls {
                    guard let bundle = Bundle(url: url)?.bundleIdentifier else {
                        continue
                    }

                    let name = FileManager.default.displayName(atPath: url.path)

                    var app = App()
                    app.name = name
                    app.bundleID = bundle
                    KeyListener.sharedKeyListener.addExcludedApp(app)
                }
                self.tableView.reloadData()
            }
        }
    }

    @IBAction func removeClicked(_ sender: AnyObject) {
        guard tableView.selectedRowIndexes.count > 0,
            let apps = KeyListener.sharedKeyListener.list else {
                return
            }

        var toRemove = [App]()
        tableView.selectedRowIndexes.forEach { index in
            toRemove.append(apps[index])
        }

        for app in toRemove {
            KeyListener.sharedKeyListener.removeExcludedApp(app)
        }

        tableView.reloadData()
    }

}
