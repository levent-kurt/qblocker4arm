//
//  TabBarController.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 29/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Cocoa

class TabBarController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        tabStyle = .segmentedControlOnTop
        // The controller synthesizes its own segmented-control header for this
        // style; suppress the raw NSTabView's native tab header underneath it.
        tabView.tabViewType = .noTabsNoBorder

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let rules = storyboard.instantiateController(withIdentifier: "Rules") as! NSViewController
        let settings = storyboard.instantiateController(withIdentifier: "Settings") as! NSViewController

        addTabViewItem(NSTabViewItem(viewController: rules))
        addTabViewItem(NSTabViewItem(viewController: settings))
    }

}
