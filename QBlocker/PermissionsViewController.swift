//
//  PermissionsViewController.swift
//  QBlocker4arm
//

import Cocoa

/// An installer-style checklist window: one row per required permission,
/// each with a live status icon and a button that opens the right System
/// Settings pane. Polls both permissions while visible and calls
/// `onAllGranted` (closing itself) as soon as both are on — no relaunch
/// needed.
final class PermissionsWindowController: NSWindowController {

    static func make(onAllGranted: @escaping () -> Void) -> PermissionsWindowController {
        let viewController = PermissionsViewController()
        viewController.onAllGranted = onAllGranted

        let window = NSWindow(contentViewController: viewController)
        window.styleMask = [.titled, .closable]
        window.title = "QBlocker4arm"
        window.isReleasedWhenClosed = false
        window.center()

        return PermissionsWindowController(window: window)
    }

}

final class PermissionsViewController: NSViewController {

    var onAllGranted: (() -> Void)?

    private var pollTimer: Timer?
    private var rows: [RequiredPermission: PermissionRowView] = [:]
    private var didGrantAll = false

    override func loadView() {
        let containerWidth: CGFloat = 420

        let titleLabel = NSTextField(labelWithString: "QBlocker4arm needs a couple of permissions")
        titleLabel.font = .boldSystemFont(ofSize: 15)

        let subtitleLabel = NSTextField(wrappingLabelWithString: "It uses these to detect and block accidental CMD+Q presses. Click a permission to open System Settings and switch it on — this window will continue on its own once both are granted.")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.preferredMaxLayoutWidth = containerWidth - 48

        let accessibilityRow = PermissionRowView(permission: .accessibility, target: self, action: #selector(rowButtonClicked(_:)))
        let inputMonitoringRow = PermissionRowView(permission: .inputMonitoring, target: self, action: #selector(rowButtonClicked(_:)))
        rows[.accessibility] = accessibilityRow
        rows[.inputMonitoring] = inputMonitoringRow

        let stack = NSStackView(views: [titleLabel, subtitleLabel, accessibilityRow, inputMonitoringRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        accessibilityRow.widthAnchor.constraint(equalToConstant: containerWidth - 48).isActive = true
        inputMonitoringRow.widthAnchor.constraint(equalToConstant: containerWidth - 48).isActive = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: 260))
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])

        self.view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshStatuses()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshStatuses()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        pollTimer?.invalidate()
        pollTimer = nil

        // Without both permissions the app can't do anything — if the user
        // closes this window before granting them, quit instead of leaving
        // a silent, do-nothing process running in the background.
        if !didGrantAll {
            NSApp.terminate(nil)
        }
    }

    @objc private func rowButtonClicked(_ sender: NSButton) {
        guard let row = rows.values.first(where: { $0.button === sender }) else {
            return
        }

        if row.permission == .inputMonitoring {
            // The first call registers the app with Input Monitoring so it
            // actually appears (and can be toggled) in System Settings.
            _ = CGRequestListenEventAccess()
        }

        if let url = URL(string: row.permission.settingsURLString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshStatuses() {
        let promptFlag = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options: CFDictionary = [promptFlag: false] as CFDictionary
        let accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        let inputMonitoringGranted = CGPreflightListenEventAccess()

        rows[.accessibility]?.setGranted(accessibilityGranted)
        rows[.inputMonitoring]?.setGranted(inputMonitoringGranted)

        if accessibilityGranted && inputMonitoringGranted {
            pollTimer?.invalidate()
            pollTimer = nil
            didGrantAll = true
            onAllGranted?()
        }
    }

}

private final class PermissionRowView: NSView {

    let permission: RequiredPermission
    let button: NSButton
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init(permission: RequiredPermission, target: AnyObject, action: Selector) {
        self.permission = permission
        button = NSButton(title: "Open Settings", target: target, action: action)
        super.init(frame: .zero)

        label.stringValue = permission.displayName
        label.font = .systemFont(ofSize: 13, weight: .medium)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded

        addSubview(iconView)
        addSubview(label)
        addSubview(button)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            button.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 28)
        ])

        setGranted(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setGranted(_ granted: Bool) {
        let symbolName = granted ? "checkmark.circle.fill" : "xmark.circle.fill"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: permission.displayName)
        iconView.image = image
        iconView.contentTintColor = granted ? .systemGreen : .systemRed
        button.isHidden = granted
    }

}
