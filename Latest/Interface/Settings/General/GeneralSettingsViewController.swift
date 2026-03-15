//
//  GeneralSettingsViewController.swift
//  Latest
//
//  Created by Max Langer on 27.12.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import AppKit
import ServiceManagement

/// Controller for settings of the General tab.
class GeneralSettingsViewController: SettingsTabItemViewController {
	
	private enum Style {
		static let includeColor = NSColor.systemOrange
		static let appearanceColor = NSColor.systemGreen
		static let windowColor = NSColor.systemBlue
		static let startupColor = NSColor.systemIndigo
	}
	
	private let includeAppsWithLimitedSupportButton = NSButton(checkboxWithTitle: NSLocalizedString("Partially supported apps", comment: "Setting title for showing apps with limited support."), target: nil, action: nil)
	private let includeUnsupportedAppsButton = NSButton(checkboxWithTitle: NSLocalizedString("Unsupported apps", comment: "Setting title for showing unsupported apps."), target: nil, action: nil)
	private let versionTextSizePopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
	private let keepInMenuBarButton = NSButton(checkboxWithTitle: NSLocalizedString("Keep Latest running after closing the main window", comment: "Setting title for keeping Latest running in the menu bar."), target: nil, action: nil)
	private let keepInDockButton = NSButton(checkboxWithTitle: NSLocalizedString("Show Latest in the Dock while hidden", comment: "Setting title for keeping Latest visible in the Dock while hidden."), target: nil, action: nil)
	private let openAtLoginButton = NSButton(checkboxWithTitle: NSLocalizedString("Open Latest at login", comment: "Setting title for starting Latest at login."), target: nil, action: nil)
	
	override func loadView() {
		self.view = NSView(frame: NSRect(origin: .zero, size: SettingsTabItemViewController.preferredSettingsContentSize))
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.preferredContentSize = SettingsTabItemViewController.preferredSettingsContentSize
		self.view.setFrameSize(self.preferredContentSize)
		self.buildInterface()
		self.refreshControls()
	}
	
	/// Whether apps with limited support should be included in the app list.
	@objc var includeAppsWithLimitedSupport: Bool {
		get {
			AppListSettings.shared.includeAppsWithLimitedSupport
		}
		set {
			AppListSettings.shared.includeAppsWithLimitedSupport = newValue
		}
	}
	
	/// Whether apps with no support should be included in the app list.
	@objc var includeUnsupportedApps: Bool {
		get {
			AppListSettings.shared.includeUnsupportedApps
		}
		set {
			AppListSettings.shared.includeUnsupportedApps = newValue
		}
	}
	
	/// The font size used for version labels in the update list.
	var versionTextSize: AppListSettings.VersionTextSize {
		get {
			AppListSettings.shared.versionTextSize
		}
		set {
			AppListSettings.shared.versionTextSize = newValue
		}
	}
	
	/// Whether Latest should remain accessible from the menu bar after its window is closed.
	@objc var keepInMenuBar: Bool {
		get {
			UpdateCheckSettings.shared.keepInMenuBar
		}
		set {
			UpdateCheckSettings.shared.keepInMenuBar = newValue
		}
	}
	
	/// Whether Latest should remain visible in the Dock while it is hidden in menu bar mode.
	@objc var keepInDock: Bool {
		get {
			UpdateCheckSettings.shared.keepInDock
		}
		set {
			UpdateCheckSettings.shared.keepInDock = newValue
		}
	}
	
	@objc private func toggleIncludeAppsWithLimitedSupport(_ sender: NSButton) {
		self.includeAppsWithLimitedSupport = sender.state == .on
	}
	
	@objc private func toggleIncludeUnsupportedApps(_ sender: NSButton) {
		self.includeUnsupportedApps = sender.state == .on
	}
	
	@objc private func changeVersionTextSize(_ sender: NSPopUpButton) {
		let selectedIndex = sender.indexOfSelectedItem
		guard let size = AppListSettings.VersionTextSize(rawValue: selectedIndex) else {
			self.refreshControls()
			return
		}
		
		self.versionTextSize = size
	}
	
	@objc private func toggleKeepInMenuBar(_ sender: NSButton) {
		self.keepInMenuBar = sender.state == .on
	}
	
	@objc private func toggleKeepInDock(_ sender: NSButton) {
		self.keepInDock = sender.state == .on
	}

	@objc private func toggleOpenAtLogin(_ sender: NSButton) {
		let shouldEnable = sender.state == .on
		
		do {
			try LoginItemService.shared.setEnabled(shouldEnable)
			self.refreshControls()
		} catch {
			self.refreshControls()
			self.presentLoginItemError(error)
		}
	}
	
	private func buildInterface() {
		self.view.subviews.forEach { $0.isHidden = true }
		
		let contentStack = NSStackView()
		contentStack.orientation = .vertical
		contentStack.alignment = .width
		contentStack.spacing = 24
		contentStack.translatesAutoresizingMaskIntoConstraints = false
		
		self.view.addSubview(contentStack)
		
		NSLayoutConstraint.activate([
			contentStack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24),
			contentStack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24),
			contentStack.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 24),
			contentStack.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor, constant: -24)
		])
		
		self.configureCheckbox(self.includeAppsWithLimitedSupportButton, action: #selector(toggleIncludeAppsWithLimitedSupport(_:)))
		self.configureCheckbox(self.includeUnsupportedAppsButton, action: #selector(toggleIncludeUnsupportedApps(_:)))
		self.configureVersionTextSizePopUp()
		self.configureCheckbox(self.keepInMenuBarButton, action: #selector(toggleKeepInMenuBar(_:)))
		self.configureCheckbox(self.keepInDockButton, action: #selector(toggleKeepInDock(_:)))
		self.configureCheckbox(self.openAtLoginButton, action: #selector(toggleOpenAtLogin(_:)))
		
		let includeSection = SettingsSectionView(
			title: NSLocalizedString("Include", comment: "Settings section title."),
			symbolName: "line.3.horizontal.decrease.circle",
			tintColor: Style.includeColor,
			items: [
				SettingsCheckboxItemView(
					button: self.includeAppsWithLimitedSupportButton,
					symbolName: "checklist.unchecked",
					tintColor: Style.includeColor,
					helper: NSLocalizedString("Show apps that Latest can track, even if updating them still happens outside the app.", comment: "Helper text for showing apps with limited support.")
				),
				SettingsCheckboxItemView(
					button: self.includeUnsupportedAppsButton,
					symbolName: "questionmark.circle",
					tintColor: Style.includeColor,
					helper: NSLocalizedString("Show apps even when Latest cannot find version or update information for them.", comment: "Helper text for showing unsupported apps.")
				)
			]
		)
		contentStack.addArrangedSubview(includeSection)
		
		let appearanceSection = SettingsSectionView(
			title: NSLocalizedString("Appearance", comment: "Settings section title."),
			symbolName: "textformat.size",
			tintColor: Style.appearanceColor,
			items: [
				SettingsPopUpItemView(
					title: NSLocalizedString("Version text size", comment: "Setting title for the version text size."),
					symbolName: "textformat",
					tintColor: Style.appearanceColor,
					popUpButton: self.versionTextSizePopUpButton,
					helper: NSLocalizedString("Makes the Your version and New version lines easier to read in the update list.", comment: "Helper text for the version text size setting.")
				)
			]
		)
		contentStack.addArrangedSubview(appearanceSection)
		
		let windowSection = SettingsSectionView(
			title: NSLocalizedString("Window", comment: "Settings section title."),
			symbolName: "macwindow",
			tintColor: Style.windowColor,
			items: [
				SettingsCheckboxItemView(
					button: self.keepInMenuBarButton,
					symbolName: "menubar.rectangle",
					tintColor: Style.windowColor,
					helper: NSLocalizedString("Close the main window without quitting. You can reopen Latest from the menu bar.", comment: "Helper text for menu bar mode.")
				),
				SettingsCheckboxItemView(
					button: self.keepInDockButton,
					symbolName: "dock.rectangle",
					tintColor: Style.windowColor,
					helper: NSLocalizedString("Turn this off to keep Latest only in the menu bar while the main window is hidden.", comment: "Helper text for Dock visibility while hidden.")
				)
			]
		)
		contentStack.addArrangedSubview(windowSection)

		let startupSection = SettingsSectionView(
			title: NSLocalizedString("Startup", comment: "Settings section title."),
			symbolName: "power.circle",
			tintColor: Style.startupColor,
			items: [
				SettingsCheckboxItemView(
					button: self.openAtLoginButton,
					symbolName: "play.circle",
					tintColor: Style.startupColor,
					helper: NSLocalizedString("Start Latest automatically after you log in to your Mac.", comment: "Helper text for launching Latest at login.")
				)
			]
		)
		contentStack.addArrangedSubview(startupSection)
		
		NSLayoutConstraint.activate([
			includeSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			includeSection.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
			appearanceSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			appearanceSection.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
			windowSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			windowSection.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
			startupSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			startupSection.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
		])
	}
	
	private func refreshControls() {
		self.includeAppsWithLimitedSupportButton.state = self.includeAppsWithLimitedSupport ? .on : .off
		self.includeUnsupportedAppsButton.state = self.includeUnsupportedApps ? .on : .off
		self.versionTextSizePopUpButton.selectItem(at: self.versionTextSize.rawValue)
		self.keepInMenuBarButton.state = self.keepInMenuBar ? .on : .off
		self.keepInDockButton.state = self.keepInDock ? .on : .off
		self.openAtLoginButton.state = LoginItemService.shared.isEnabled ? .on : .off
		self.openAtLoginButton.isEnabled = LoginItemService.shared.isSupported
	}
	
	private func configureCheckbox(_ button: NSButton, action: Selector) {
		button.target = self
		button.action = action
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setButtonType(.switch)
	}
	
	private func configureVersionTextSizePopUp() {
		self.versionTextSizePopUpButton.removeAllItems()
		self.versionTextSizePopUpButton.addItems(withTitles: AppListSettings.VersionTextSize.allCases.map(\.displayName))
		self.versionTextSizePopUpButton.target = self
		self.versionTextSizePopUpButton.action = #selector(changeVersionTextSize(_:))
	}

	private func presentLoginItemError(_ error: Error) {
		let alert = NSAlert()
		alert.messageText = NSLocalizedString("Couldn’t Change Login Setting", comment: "Alert title shown when changing the login item setting fails.")
		alert.informativeText = error.localizedDescription
		alert.alertStyle = .warning
		
		if let window = self.view.window {
			alert.beginSheetModal(for: window)
		} else {
			alert.runModal()
		}
	}
}

private final class LoginItemService {
	static let shared = LoginItemService()
	
	private init() {}
	
	var isSupported: Bool {
		if #available(macOS 13.0, *) {
			return true
		}
		
		return false
	}
	
	var isEnabled: Bool {
		guard #available(macOS 13.0, *) else {
			return false
		}
		
		switch SMAppService.mainApp.status {
		case .enabled, .requiresApproval:
			return true
		case .notFound, .notRegistered:
			return false
		@unknown default:
			return false
		}
	}
	
	func setEnabled(_ enabled: Bool) throws {
		guard #available(macOS 13.0, *) else {
			throw LoginItemError.unsupported
		}
		
		let service = SMAppService.mainApp
		
		if enabled {
			guard service.status != .enabled else {
				return
			}
			
			try service.register()
		} else {
			guard service.status == .enabled || service.status == .requiresApproval else {
				return
			}
			
			try service.unregister()
		}
	}
	
	private enum LoginItemError: LocalizedError {
		case unsupported
		
		var errorDescription: String? {
			switch self {
			case .unsupported:
				NSLocalizedString("Open at login requires macOS 13 or later.", comment: "Error description shown when open-at-login is not supported on the current macOS version.")
			}
		}
	}
}
