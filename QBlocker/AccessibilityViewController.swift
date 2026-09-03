//
//  AccessibilityViewController.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 05/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

class AccessibilityViewController: NSViewController {

    @IBAction func openPreferences(_ sender: AnyObject) {

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        // Quit the app — the accessibility trust check only runs at launch,
        // so the user needs to re-open it after granting permission.
        NSApp.terminate(self)
    }



}
