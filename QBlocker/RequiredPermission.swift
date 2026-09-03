//
//  RequiredPermission.swift
//  QBlocker4arm
//

import Foundation

/// The two macOS privacy permissions QBlocker4arm needs to intercept CMD+Q:
/// Accessibility (to read a frontmost app's menu bar) and Input Monitoring
/// (to actually create a system-wide keyboard event tap — a separate
/// permission from Accessibility since macOS Catalina).
enum RequiredPermission: Hashable {
    case accessibility
    case inputMonitoring

    var displayName: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        }
    }

    var settingsURLString: String {
        switch self {
        case .accessibility: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring: return "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
    }
}
