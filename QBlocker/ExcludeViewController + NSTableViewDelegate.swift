//
//  ExcludeViewController + NSTableViewDelegate.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 07/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

extension ExcludeViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("app name cell"), owner: nil) as? NSTableCellView,
            let app = KeyListener.sharedKeyListener.list?[row] else {
                return nil
        }

        cell.textField?.stringValue = app.name
        return cell
    }

}
