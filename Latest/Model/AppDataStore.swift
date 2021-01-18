//
//  AppCollection.swift
//  Latest
//
//  Created by Max Langer on 15.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Foundation

/// The collection handling the apps
/// This structure supports the following states:
/// - All apps with updates available
/// - All installed apps, separated from the ones with updates through sections
/// - A filtered list of apps based on a given filter string
class AppDataStore {
	
	// MARK: - Delegate Scheduling
		
	/// Schedules an update notification.
	private let filterScheduler: DispatchSourceUserDataAdd
	
	init() {
		let source = DispatchSource.makeUserDataAddSource(queue: .global())
		self.filterScheduler = source

		// Delay notifying observers to only let that notification occur in a certain interval
		source.setEventHandler() { [unowned self] in
			self.filterApps()
			self.notifyObservers(newValue: self.filteredApps)
		
			// Delay the next call for 0.6 seconds
			Thread.sleep(forTimeInterval: 0.6)
		}
		
		source.activate()
	}
	
	
	// MARK: - Filtering
	
	/// The collection holding all apps that have been found.
	private var apps = Set<AppBundle>()
	
	/// A subset of apps that can be updated. Ignored apps are not part of this list.
	var updateableApps: [AppBundle] {
		return self.apps.filter({ $0.updateAvailable && !self.isAppIgnored($0) && !($0 is MacAppStoreAppBundle) })
	}
	
	/// The user-facable, sorted and filtered list of apps and sections. Observers of the data store will be notified, when this list changes.
	private(set) var filteredApps = [Entry]()
	
	/// The query after which apps can be filtered
	var filterQuery: String? {
		didSet {
			// Cleanup empty filter queries
			if self.filterQuery?.isEmpty ?? false {
				self.filterQuery = nil
			}
			
			// Always lowercase query
			self.filterQuery = self.filterQuery?.lowercased()
			self.filterApps()
		}
	}
	
	/// Sorts and filters all available apps based on the given filter criteria.
	private func filterApps() {
		objc_sync_enter(self);
		var visibleApps = self.apps
		let ignoredApps = visibleApps.filter({ self.ignoredAppIdentifiers.contains($0.bundleIdentifier) })
		
		// Filter installed updates
		if !self.showInstalledUpdates {
			visibleApps = visibleApps.filter({ $0.updateAvailable })
		}
		
		// Filter unsupported apps
		if !self.showUnsupportedUpdates {
			visibleApps = visibleApps.filter({ type(of: $0).supported })
		}
        
        // Filter in-app apps
        if !self.showInAppUpdates {
            visibleApps = visibleApps.filter({ !$0.url.path.contains(".app/") })
        }
		
		// Apply filter query
		if let filterQuery = self.filterQuery {
			visibleApps = visibleApps.filter({ $0.name.lowercased().contains(filterQuery) })
		}
		
		// Filter ignored apps
		if !self.showIgnoredUpdates {
			visibleApps = visibleApps.filter({ !ignoredApps.contains($0) })
		}
		
		// Sort apps
		let filteredApps = visibleApps.sorted(by: { (app1, app2) -> Bool in
			return app1.name.lowercased() < app2.name.lowercased()
		})
		
		// Build final list. This is a very inefficient solution. Find a better one
		var availableUpdates = filteredApps.filter({ $0.updateAvailable && !self.isAppIgnored($0) }).map({ Entry.app($0) })
		if !availableUpdates.isEmpty {
			availableUpdates = [.section(Self.updatableAppsSection(withCount: availableUpdates.count))] + availableUpdates
		}
		
		var installedUpdates = filteredApps.filter({ !$0.updateAvailable && !self.isAppIgnored($0) }).map({ Entry.app($0) })
		if !installedUpdates.isEmpty {
			installedUpdates = [.section(Self.updatedAppsSection(withCount: installedUpdates.count))] + installedUpdates
		}
		
		var ignoredUpdates = filteredApps.filter({ self.isAppIgnored($0) }).map({ Entry.app($0) })
		if !ignoredUpdates.isEmpty {
			ignoredUpdates = [.section(Self.ignoredAppsSection(withCount: ignoredUpdates.count))] + ignoredUpdates
		}
		
		self.filteredApps = availableUpdates + installedUpdates + ignoredUpdates
		objc_sync_exit(self);
	}
	
	/// The cached count of apps with updates available
	private(set) var countOfAvailableUpdates: Int = 0
	
    /// Adds a new app to the collection
	func update(_ app: AppBundle) {
		if let oldApp = self.apps.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
			self.apps.remove(oldApp)
			self.pendingApps?.remove(oldApp)
			
			if !self.isAppIgnored(oldApp) {
				self.countOfAvailableUpdates -= oldApp.updateAvailable ? 1 : 0
			}
		}
		
        self.apps.insert(app)
		
		if !self.isAppIgnored(app) {
			self.countOfAvailableUpdates += app.updateAvailable ? 1 : 0
		}
		
		// Schedule an update for observers
		self.scheduleFilterUpdate()
    }
	
	
	// MARK: - Accessors
	
    /// Whether installed apps should be visible
	var showInstalledUpdates = false {
		didSet {
			self.scheduleFilterUpdate()
		}
	}
	
	/// Whether ignored apps should be visible
	var showIgnoredUpdates = false {
		didSet {
			self.scheduleFilterUpdate()
		}
	}
	
	/// Whether unsupported apps should be visible
	var showUnsupportedUpdates = false {
		didSet {
			self.scheduleFilterUpdate()
		}
	}
    
    /// Whether in-app apps should be visible
    var showInAppUpdates = false {
        didSet {
            self.scheduleFilterUpdate()
        }
    }
	
	/// Returns the app at the given index, if any.
	func app(at index: Int) -> AppBundle? {
		if case .app(let app) = self.filteredApps[index] {
			return app
		}
		
		return nil
	}
	
    /// Returns whether there is a section at the given index
    func isSectionHeader(at index: Int) -> Bool {
		if case .section(_) = self.filteredApps[index] {
			return true
		}
		
		return false
    }
	
	
	// MARK: - Ignoring Apps
	
	/// The key for storing a list of ignored apps.
	private static let IgnoredAppsKey = "IgnoredAppsKey"

	/// Whether the given app is ignored.
	func isAppIgnored(_ app: AppBundle) -> Bool {
		return self.ignoredAppIdentifiers.contains(app.bundleIdentifier)
	}
	
	/// Sets the ignored state of the given app.
	func setIgnored(_ ignored: Bool, for app: AppBundle) {
		var ignoredApps = self.ignoredAppIdentifiers
		
		if ignored {
			ignoredApps.insert(app.bundleIdentifier)
		} else {
			ignoredApps.remove(app.bundleIdentifier)
		}

		UserDefaults.standard.set(Array(ignoredApps), forKey: Self.IgnoredAppsKey)
		
		self.updateCountOfAvailableApps()
		self.scheduleFilterUpdate()
	}
	
	/// Returns the identifiers of ignored apps.
	private var ignoredAppIdentifiers: Set<String> {
		return Set((UserDefaults.standard.array(forKey: Self.IgnoredAppsKey) as? [String]) ?? [])
	}
	
	
	// MARK: - Update Process
	
	/// A temporare set of all apps that need to be updated in the current update pass.
	private var pendingApps: Set<AppBundle>?
	
	/// Begins one update pass. Every app in the data store has to be marked as updated, otherwise it will be removed on `endUpdates`.
	func beginUpdates() {
		guard self.pendingApps == nil else { fatalError("Update is currently running.") }
		
		// Set our current state as pending
		self.pendingApps = self.apps
	}
	
	/// Ends current the update pass.
	func endUpdates() {
		guard let pendingApps = self.pendingApps else { fatalError("No update was initiated previously.") }
		
		// Remove all apps that have not been updated
		self.apps.subtract(pendingApps)
		self.pendingApps = nil
	
		self.updateCountOfAvailableApps()
		self.scheduleFilterUpdate()
	}
	
	/// Updates the count of all available apps.
	private func updateCountOfAvailableApps() {
		self.countOfAvailableUpdates = self.apps.filter({ $0.updateAvailable && !self.ignoredAppIdentifiers.contains($0.bundleIdentifier) }).count
	}
	
	
	// MARK: - Observer Handling
	
	/// The handler for notifying observers about changes to the update state.
	typealias ObserverHandler = (_ newValue: [Entry]) -> Void

	/// A mapping of observers assotiated with apps.
	private var observers = [NSObject: ObserverHandler]()
	
	/// Adds the observer if it is not already registered.
	func addObserver(_ observer: NSObject, handler: @escaping ObserverHandler) {
		guard !self.observers.keys.contains(observer) else { return }
		self.observers[observer] = handler
		
		// Call handler immediately to propagate initial state
		handler(self.filteredApps)
	}
	
	/// Remvoes the observer.
	func removeObserver(_ observer: NSObject, for app: AppBundle) {
		self.observers.removeValue(forKey: observer)
	}
		
	/// Notifies observers about state changes.
	private func notifyObservers(newValue: [Entry]) {
		DispatchQueue.main.async {
			self.observers.forEach { (key: NSObject, handler: ObserverHandler) in
				handler(newValue)
			}
		}
	}
	
	/// Schedules an filter update and notifies observers of the updated app list
	private func scheduleFilterUpdate() {
		self.filterScheduler.add(data: 1)
	}
	
	
	// MARK: - Section Builder
	
	private static func updatableAppsSection(withCount numberOfApps: Int) -> Section {
		let title = NSLocalizedString("Available Updates", comment: "Table Section Header for available updates")
		let shortTitle = NSLocalizedString("Available", comment: "Touch Bar section title for available updates")
		return Section(title: title, shortTitle: shortTitle, numberOfApps: numberOfApps)
	}
	
	private static func updatedAppsSection(withCount numberOfApps: Int) -> Section {
		let title = NSLocalizedString("Installed Apps", comment: "Table Section Header for already installed apps")
		let shortTitle = NSLocalizedString("Installed", comment: "Touch Bar section title for installed apps")
		return Section(title: title, shortTitle: shortTitle, numberOfApps: numberOfApps)
	}

	private static func ignoredAppsSection(withCount numberOfApps: Int) -> Section {
		let title = NSLocalizedString("Ignored Apps", comment: "Table Section Header for ignored apps")
		let shortTitle = NSLocalizedString("Ignored", comment: "Touch Bar section title for ignored apps")
		return Section(title: title, shortTitle: shortTitle, numberOfApps: numberOfApps)
	}

}

extension AppDataStore {
	
	/// Defines one entry in the filtered update.
	enum Entry: Equatable, Hashable {
		
		/// Represents one app in the list.
		case app(AppBundle)
		
		/// Represents one section header in the list.
		case section(Section)
		
	}
	
	/// A section used for grouping multiple results.
	struct Section: Equatable, Hashable {
		
		/// The title of the section.
		let title: String
		
		/// A shorter representation of the sections title.
		let shortTitle: String
		
		/// The number of apps this section encloses.
		let numberOfApps: Int
		
		
		// MARK: - Protocol Overrides
		
		/// Exclude the number of apps from the function
		static func ==(lhs: Section, rhs: Section) -> Bool {
			return lhs.title == rhs.title
		}
		
		/// Exclude the number of apps from the function
		func hash(into hasher: inout Hasher) {
			hasher.combine(title)
		}
		
	}
}
