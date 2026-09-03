//
//  AccessibilityWindowController.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 05/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

class AccessibilityWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.titlebarAppearsTransparent = true
        window?.backgroundColor = NSColor(calibratedHue: 0.00, saturation: 0.00, brightness: 0.90, alpha: 1.00)
        // This window's background is a fixed light color, so pin it to the light
        // appearance — otherwise labelColor text resolves to near-white in Dark Mode.
        window?.appearance = NSAppearance(named: .aqua)
    }

}
