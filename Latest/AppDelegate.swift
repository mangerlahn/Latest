//
//  AppDelegate.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import Sparkle

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, Observer {

	var id = UUID()
	
	private static let statusBadgeFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		return formatter
	}()
	
	/// The window controller of the app's main window.
	private weak var mainWindowController: MainWindowController?
	
	/// The window controller of the app's Settings window.
	private lazy var settingsWindowController = SettingsWindowController()
	
	/// The status item keeping Latest accessible from the menu bar.
	private var statusItem: NSStatusItem?

	/// Sparkle controller responsible for updating Latest itself.
	@IBOutlet private weak var standardUpdaterController: SPUStandardUpdaterController?
	
	/// The timer scheduling automatic update checks while the app is running.
	private var automaticCheckTimer: Timer?
	
	/// Whether the initial automation setup has already been performed.
	private var didConfigureAutomation = false
	
    func applicationDidFinishLaunching(_ aNotification: Notification) {
		UpdateCheckSettings.shared.add(self, handler: self.updateRuntimeConfiguration)
		AppListSettings.shared.add(self, handler: self.updateApplicationBadges)
		UpdateCheckCoordinator.shared.appProvider.addObserver(self) { [weak self] _ in
			self?.updateApplicationBadges()
		}
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(runAutomaticUpdateCheckIfDue), name: NSWorkspace.didWakeNotification, object: nil)
		self.configurePreferencesMenuItem()
		DispatchQueue.main.async { [weak self] in
			self?.configurePreferencesMenuItem()
		}
		self.updateRuntimeConfiguration()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
		UpdateCheckSettings.shared.remove(self)
		AppListSettings.shared.remove(self)
		UpdateCheckCoordinator.shared.appProvider.removeObserver(self)
		NSWorkspace.shared.notificationCenter.removeObserver(self)
		self.automaticCheckTimer?.invalidate()
    }
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		!UpdateCheckSettings.shared.keepInMenuBar
	}
	
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		guard !flag else {
			return false
		}
		
		self.showMainWindow(nil)
		return true
	}

	// MARK: - Automation
	
	/// Registers the given main window controller for later reopening.
	func register(mainWindowController: MainWindowController) {
		self.mainWindowController = mainWindowController
	}
	
	/// Applies all runtime configuration controlled by user preferences.
	private func updateRuntimeConfiguration() {
		self.configureStatusItemIfNeeded()
		self.updateActivationPolicy()
		self.scheduleAutomaticChecksIfNeeded()
		self.updateApplicationBadges()
	}
	
	/// Ensures that resident UI is visible before the app hides its main window.
	func enterBackgroundMode() {
		self.configureStatusItemIfNeeded()
		self.updateActivationPolicy()
	}

	private func configureStatusItemIfNeeded() {
		guard UpdateCheckSettings.shared.keepInMenuBar else {
			if let statusItem {
				NSStatusBar.system.removeStatusItem(statusItem)
			}
			
			self.statusItem = nil
			return
		}
		
		guard self.statusItem == nil else {
			return
		}
		
		let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		self.configureStatusButton(statusItem.button)
		statusItem.menu = self.makeStatusMenu()
		self.statusItem = statusItem
	}
	
	private func configureStatusButton(_ button: NSStatusBarButton?) {
		guard let button else {
			return
		}
		
		let applicationName = Bundle.main.localizedInfoDictionary?[kCFBundleNameKey as String] as? String ?? "Latest"
		let updateCount = self.displayedAvailableUpdateCount
		
		if #available(macOS 11.0, *) {
			let image = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: applicationName)
			image?.isTemplate = true
			button.image = image
			button.imagePosition = .imageLeft
			button.title = updateCount > 0 ? "\(updateCount)" : ""
			button.attributedTitle = updateCount > 0 ? self.statusItemBadgeTitle(for: updateCount) : NSAttributedString(string: "")
		} else {
			button.image = nil
			button.title = updateCount > 0 ? "\(applicationName) (\(updateCount))" : applicationName
		}
		
		button.imageScaling = .scaleProportionallyDown
		button.toolTip = updateCount == 1 ? "\(applicationName): 1 update available" : "\(applicationName): \(updateCount) updates available"
	}
	
	private func updateStatusItemAppearance() {
		self.statusItem?.length = self.displayedAvailableUpdateCount == 0 ? NSStatusItem.squareLength : NSStatusItem.variableLength
		self.configureStatusButton(self.statusItem?.button)
	}
	
	private func updateApplicationBadges() {
		self.updateStatusItemAppearance()
		self.updateDockBadge()
	}
	
	private func updateActivationPolicy() {
		let shouldHideDock = UpdateCheckSettings.shared.keepInMenuBar && !UpdateCheckSettings.shared.keepInDock && !self.isMainWindowVisible
		NSApp.setActivationPolicy(shouldHideDock ? .accessory : .regular)
		self.updateDockBadge()
	}

	private func updateDockBadge() {
		let badgeLabel = self.displayedAvailableUpdateCount == 0 ? nil : Self.statusBadgeFormatter.string(from: self.displayedAvailableUpdateCount as NSNumber)
		NSApplication.shared.dockTile.badgeLabel = badgeLabel
		NSApplication.shared.dockTile.display()
	}

	private func makeStatusMenu() -> NSMenu {
		let menu = NSMenu()
		menu.addItem(withTitle: NSLocalizedString("Open Latest", comment: "Menu bar item action to open the main window."), action: #selector(showMainWindow(_:)), keyEquivalent: "")
		menu.addItem(withTitle: NSLocalizedString("Settings", comment: "Menu bar item action to open the settings window."), action: #selector(showSettings(_:)), keyEquivalent: "")
		menu.addItem(withTitle: NSLocalizedString("Check for Updates", comment: "Menu bar item action to check for updates."), action: #selector(checkForUpdates(_:)), keyEquivalent: "")
		menu.addItem(.separator())
		menu.addItem(withTitle: NSLocalizedString("Quit Latest", comment: "Menu bar item action to quit the app."), action: #selector(quit(_:)), keyEquivalent: "")
		menu.items.forEach { $0.target = self }
		
		return menu
	}

	private func scheduleAutomaticChecksIfNeeded() {
		self.automaticCheckTimer?.invalidate()
		self.automaticCheckTimer = nil
		
		let schedule = UpdateCheckSettings.shared.automaticCheckSchedule
		guard let interval = schedule.interval else {
			self.didConfigureAutomation = true
			return
		}

		let timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(runAutomaticUpdateCheckIfDue), userInfo: nil, repeats: true)
		timer.tolerance = interval * 0.1
		self.automaticCheckTimer = timer
		
		if self.didConfigureAutomation {
			self.runAutomaticUpdateCheckIfDue()
		}
		
		self.didConfigureAutomation = true
	}
	
	private func configurePreferencesMenuItem() {
		guard
			let applicationMenu = NSApp.mainMenu?.item(at: 0)?.submenu,
			let preferencesItem = applicationMenu.items.first(where: { $0.keyEquivalent == "," })
		else {
			return
		}
		
		preferencesItem.target = self
		preferencesItem.action = #selector(showSettings(_:))
	}
	
	@objc private func runAutomaticUpdateCheckIfDue() {
		let schedule = UpdateCheckSettings.shared.automaticCheckSchedule
		guard schedule.isDue(since: UpdateCheckSettings.shared.lastAutomaticCheckDate) else {
			return
		}
		
		UpdateCheckSettings.shared.lastAutomaticCheckDate = Date()
		UpdateCheckCoordinator.shared.run()
	}
	
	
	// MARK: - Actions
	
	@objc func showMainWindow(_ sender: Any?) {
		self.mainWindowController?.showWindow(sender)
		self.mainWindowController?.window?.makeKeyAndOrderFront(sender)
		self.updateActivationPolicy()
		NSApp.activate(ignoringOtherApps: true)
	}
	
	@objc func checkForUpdates(_ sender: Any?) {
		self.showMainWindow(sender)
		UpdateCheckCoordinator.shared.run()
	}
	
	@objc func showSettings(_ sender: Any?) {
		self.updateActivationPolicy()
		self.settingsWindowController.showWindow(sender)
		self.settingsWindowController.window?.makeKeyAndOrderFront(sender)
		NSApp.activate(ignoringOtherApps: true)
	}

	@objc func showPreferencesWindow(_ sender: Any?) {
		self.showSettings(sender)
	}

	@objc func showSettingsWindow(_ sender: Any?) {
		self.showSettings(sender)
	}
	
	@objc func quit(_ sender: Any?) {
		NSApp.terminate(sender)
	}
	
	private var displayedAvailableUpdateCount: Int {
		let showExternalUpdates = AppListSettings.shared.includeAppsWithLimitedSupport
		return UpdateCheckCoordinator.shared.appProvider.countOfAvailableUpdates(where: { showExternalUpdates || $0.usesBuiltInUpdater })
	}
	
	private func statusItemBadgeTitle(for updateCount: Int) -> NSAttributedString {
		NSAttributedString(
			string: String(updateCount),
			attributes: [
				.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
			]
		)
	}

	private var isMainWindowVisible: Bool {
		self.mainWindowController?.window?.isVisible == true
	}

	var automaticallyChecksForSelfUpdates: Bool {
		get {
			self.standardUpdaterController?.updater.automaticallyChecksForUpdates ?? false
		}
		set {
			self.standardUpdaterController?.updater.automaticallyChecksForUpdates = newValue
		}
	}
	    
}
