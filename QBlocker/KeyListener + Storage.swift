//
//  KeyListener + Storage.swift
//  QBlocker4arm
//
//  Created by Stephen Radford on 07/05/2016.
//  Copyright © 2016 Cocoon Development Ltd. All rights reserved.
//

import Foundation

/// Persists the excluded-apps list as JSON in Application Support
enum ExcludedAppsStore {

    private static let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("QBlocker4arm", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("excludedApps.json")
    }()

    static func load() -> [App] {
        guard let data = try? Data(contentsOf: fileURL),
            let apps = try? JSONDecoder().decode([App].self, from: data) else {
                return []
        }
        return apps
    }

    static func save(_ apps: [App]) {
        guard let data = try? JSONEncoder().encode(apps) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

}

extension KeyListener {

    /**
     Add an excluded app to the store

     - parameter app: The app to be added
     */
    func addExcludedApp(_ app: App) {
        var apps = ExcludedAppsStore.load()
        apps.removeAll { $0.bundleID == app.bundleID }
        apps.append(app)
        ExcludedAppsStore.save(apps)
    }

    /**
     Remove an app from the store

     - parameter app: The app to be removed
     */
    func removeExcludedApp(_ app: App) {
        var apps = ExcludedAppsStore.load()
        apps.removeAll { $0.bundleID == app.bundleID }
        ExcludedAppsStore.save(apps)
    }

}
