//
//  GeneralSettingsViewController.swift
//  Latest
//
//  Created by Max Langer on 27.12.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import AppKit

/// Controller for settings of the General tab.
class GeneralSettingsViewController: SettingsTabItemViewController {
	
	private enum Style {
		static let includeColor = NSColor.systemOrange
		static let windowColor = NSColor.systemBlue
	}
	
	private let includeAppsWithLimitedSupportButton = NSButton(checkboxWithTitle: NSLocalizedString("Partially supported apps", comment: "Setting title for showing apps with limited support."), target: nil, action: nil)
	private let includeUnsupportedAppsButton = NSButton(checkboxWithTitle: NSLocalizedString("Unsupported apps", comment: "Setting title for showing unsupported apps."), target: nil, action: nil)
	private let keepInMenuBarButton = NSButton(checkboxWithTitle: NSLocalizedString("Keep Latest running after closing the main window", comment: "Setting title for keeping Latest running in the menu bar."), target: nil, action: nil)
	private let keepInDockButton = NSButton(checkboxWithTitle: NSLocalizedString("Show Latest in the Dock while hidden", comment: "Setting title for keeping Latest visible in the Dock while hidden."), target: nil, action: nil)
	
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
	
	@objc private func toggleKeepInMenuBar(_ sender: NSButton) {
		self.keepInMenuBar = sender.state == .on
	}
	
	@objc private func toggleKeepInDock(_ sender: NSButton) {
		self.keepInDock = sender.state == .on
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
		self.configureCheckbox(self.keepInMenuBarButton, action: #selector(toggleKeepInMenuBar(_:)))
		self.configureCheckbox(self.keepInDockButton, action: #selector(toggleKeepInDock(_:)))
		
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
		
		NSLayoutConstraint.activate([
			includeSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			includeSection.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
			windowSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			windowSection.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
		])
	}
	
	private func refreshControls() {
		self.includeAppsWithLimitedSupportButton.state = self.includeAppsWithLimitedSupport ? .on : .off
		self.includeUnsupportedAppsButton.state = self.includeUnsupportedApps ? .on : .off
		self.keepInMenuBarButton.state = self.keepInMenuBar ? .on : .off
		self.keepInDockButton.state = self.keepInDock ? .on : .off
	}
	
	private func configureCheckbox(_ button: NSButton, action: Selector) {
		button.target = self
		button.action = action
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setButtonType(.switch)
	}
}
