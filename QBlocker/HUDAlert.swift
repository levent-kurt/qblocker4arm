//
//  HUDAlert.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 03/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

class HUDAlert {

    /// Shared instance
    static let sharedHUDAlert = HUDAlert()

    /// The window that will be used to display the HUD alert
    var window: NSWindow?

    /// The dismiss work item that can be cancelled if the HUD is displayed again during that time
    var dismissWorkItem: DispatchWorkItem?

    init() {
        window = NSWindow(contentRect: NSMakeRect(0, 0, 426, 79), styleMask: .borderless, backing: .buffered, defer: false)
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        window?.isOpaque = false
        window?.backgroundColor = NSColor.clear

        let vc = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "Alert") as! NSViewController
        window?.contentView = vc.view
        window?.contentView?.wantsLayer = true

        window?.makeKey()
    }

    /**
     Show the HUD window
     */
    func showHUD(_ delayTime: TimeInterval? = nil) {

        guard let screenRect = NSScreen.main?.visibleFrame else {
            print("Could not get screen frame")
            return
        }

        dismissWorkItem?.cancel()

        let newRect = NSMakeRect((screenRect.size.width - 426) * 0.5, (screenRect.size.height - 79) * 0.5, 426, 79)
        window?.setFrame(newRect, display: true)
        window?.makeKeyAndOrderFront(self)

        if let delayTime = delayTime {
            let workItem = DispatchWorkItem { [weak self] in
                self?.dismissHUD()
            }
            dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: workItem)
        }
    }

    /**
     Dismiss the HUD window
     */
    func dismissHUD(_ fade: Bool = true) {

        guard fade else {
            self.window?.orderOut(self)
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            self.window?.contentView?.animator().alphaValue = 0
        }) {
            self.window?.orderOut(self)
            self.window?.contentView?.alphaValue = 1
        }

    }

}
