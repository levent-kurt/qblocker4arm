//
//  AtLogin.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 04/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Foundation
import ServiceManagement

/**
 *  Handle the launch at login settings for the app
 */
struct AtLogin {

    /// Whether launch at login is enabled or not
    static var enabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /**
     Toggle launch at login
     */
    static func toggle() {
        do {
            if enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Could not toggle login item: \(error)")
        }
    }

}
