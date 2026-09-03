//
//  ExcludeViewController + NSTableViewDataSource.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 07/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

extension ExcludeViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return KeyListener.sharedKeyListener.list?.count ?? 0
    }

}
