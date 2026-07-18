//
//  SettingsWindowController.swift
//  Latest
//
//  Created by Codex on 02.01.25.
//

import AppKit

/// Window controller hosting the app's Settings window without relying on storyboard scenes.
final class SettingsWindowController: NSWindowController {
	
	private let settingsTabViewController = SettingsTabViewController()
	
	init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 760, height: 420),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = NSLocalizedString("Settings", comment: "Title of the settings window.")
		window.setFrameAutosaveName("SettingsWindow")
		window.isReleasedWhenClosed = false
		window.animationBehavior = .default
		window.tabbingMode = .disallowed
		
		super.init(window: window)
		
		self.settingsTabViewController.tabStyle = .toolbar
		self.configureTabs()
		window.contentViewController = self.settingsTabViewController
		window.center()
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func configureTabs() {
		let tabs: [(viewController: NSViewController, image: NSImage?)] = [
			self.makeGeneralViewController(),
			self.makeAutomationViewController(),
			self.makeLocationsViewController()
		]
		
		tabs.forEach { tab in
			self.settingsTabViewController.addChild(tab.viewController)
		}
		
		for (index, tab) in tabs.enumerated() where index < self.settingsTabViewController.tabViewItems.count {
			self.settingsTabViewController.tabViewItems[index].image = tab.image
		}
	}
	
	private func makeGeneralViewController() -> (viewController: NSViewController, image: NSImage?) {
		let viewController = GeneralSettingsViewController()
		viewController.title = NSLocalizedString("General", comment: "Settings tab title.")
		return (
			viewController,
			self.makeTabImage(systemSymbolName: "gearshape", fallbackName: NSImage.preferencesGeneralName)
		)
	}
	
	private func makeAutomationViewController() -> (viewController: NSViewController, image: NSImage?) {
		let viewController = AutomationSettingsViewController()
		viewController.title = NSLocalizedString("Automation", comment: "Settings tab title.")
		return (
			viewController,
			self.makeTabImage(systemSymbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90", fallbackName: NSImage.refreshTemplateName)
		)
	}
	
	private func makeLocationsViewController() -> (viewController: NSViewController, image: NSImage?) {
		let viewController = AppDirectoryViewController()
		viewController.title = NSLocalizedString("Locations", comment: "Settings tab title.")
		return (
			viewController,
			self.makeTabImage(systemSymbolName: "externaldrive", fallbackName: "PreferencesLocation")
		)
	}
	
	private func makeTabImage(systemSymbolName: String, fallbackName: String) -> NSImage? {
		if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil) {
			return image
		}
		
		return NSImage(named: NSImage.Name(fallbackName))
	}
}
