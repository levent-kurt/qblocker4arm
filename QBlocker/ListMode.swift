//
//  ListMode.swift
//  QBlocker4arm
//
//  Created by Florian Schliep on 25.05.16.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Foundation

enum ListMode: Int {
    case blacklist = 0
    case whitelist = 1

    static var selectedMode: ListMode {
        return ListMode(rawValue: UserDefaults.standard.integer(forKey: "listMode")) ?? .whitelist
    }

    func select() {
        UserDefaults.standard.set(self.rawValue, forKey: "listMode")
    }
}
