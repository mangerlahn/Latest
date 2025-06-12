//
//  AppCollection.swift
//  Latest
//
//  Created by Max Langer on 15.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Foundation

/// An interface for objects providing apps.
protocol AppProviding {
	
	/// Returns a list of apps with available updates that can be updated from within Latest.
	var updatableApps: [App] { get }

	/// Returns the number of apps with updates available.
	func countOfAvailableUpdates(where condition: (App) -> Bool) -> Int
	
	/// The handler for notifying observers about changes to the update state.
	typealias ObserverHandler = (_ newValue: [App]) -> Void

	/// Adds the observer if it is not already registered.
	func addObserver(_ observer: NSObject, handler: @escaping ObserverHandler)
	
	/// Removes the observer.
	func removeObserver(_ observer: NSObject)
	
	/// Sets the ignored state for the given app.
	func setIgnoredState(_ ignored: Bool, for app: App)
	
}

/// The collection handling app bundles alongside there update representations.
class AppDataStore: AppProviding {
	
	/// The queue on which updates to the collection are being performed.
	private var updateQueue = DispatchQueue(label: "DataStoreQueue")
	
	
	init() {
		self.updateScheduler = DispatchSource.makeUserDataAddSource(queue: .global())
		self.setupScheduler()
	}

	
	// MARK: - Delegate Scheduling

	/// Schedules an update notification.
	private let updateScheduler: DispatchSourceUserDataAdd
	
	/// Sets up the scheduler.
	private func setupScheduler() {
		// Delay notifying observers to only let that notification occur in a certain interval
		updateScheduler.setEventHandler() { [unowned self] in
			updateQueue.sync {
				let apps = Array(self.apps)
				self.notifyObservers(apps)
			}
		
			// Delay the next call for 0.6 seconds
			Thread.sleep(forTimeInterval: 0.6)
		}
		
		updateScheduler.activate()
	}
	
	/// Schedules an filter update and notifies observers of the updated app list
	private func scheduleFilterUpdate() {
		self.updateScheduler.add(data: 1)
	}
	
	
	// MARK: - App Providing
	
	/// The collection holding all apps that have been found.
	private(set) var apps = Set<App>() {
		didSet {
			// Schedule an update for observers
			self.scheduleFilterUpdate()
		}
	}
	
	/// A subset of apps that can be updated. Ignored apps are not part of this list.
	var updatableApps: [App] {
		updateQueue.sync {
			return self.apps.filter({ $0.updateAvailable && $0.usesBuiltInUpdater && !$0.isIgnored })
		}
	}
		
	/// The cached count of apps with updates available
	func countOfAvailableUpdates(where condition: (App) -> Bool) -> Int {
		updateQueue.sync {
			return self.apps.filter({ $0.updateAvailable && !$0.isIgnored && condition($0) }).count
		}
	}
	
	/// Updates the store with the given set of app bundles.
	///
	/// It returns a set with matching app objects, containing the given bundles with their associated updates.
	func set(appBundles: Set<App.Bundle>) -> Set<App> {
		self.updateQueue.sync {
			let oldApps = self.apps
			self.apps = Set(appBundles.map({ bundle in
				if let app = oldApps.first(where: { $0.identifier == bundle.identifier }) {
					return app.with(bundle: bundle)
				}
				
				return App(bundle: bundle, update: nil, isIgnored: self.isIdentifierIgnored(bundle.bundleIdentifier))
			}))
			
			return self.apps.subtracting(oldApps)
		}
	}
	
	/// Sets the given update for the given bundle and returns the combined object.
	func set(_ update: Result<App.Update, Error>?, for bundle: App.Bundle) -> App {
		self.updateQueue.sync {
			guard let oldApp = self.apps.first(where: { $0.bundle == bundle }) else {
				fatalError("App not in data store")
			}
			
			let app = App(bundle: bundle, update: update, isIgnored: oldApp.isIgnored)
			self.update(app)
			
			return app
		}
	}
	
	/// Replaces an existing app entry in the data store with the given one.
	private func update(_ app: App) {
		if let oldApp = self.apps.first(where: { $0.identifier == app.identifier }) {
			self.apps.remove(oldApp)
		}
		
		self.apps.insert(app)
	}
	
	
	// MARK: - Ignoring Apps
	
	/// The key for storing a list of ignored apps.
	private static let IgnoredAppsKey = "IgnoredAppsKey"

	/// Returns whether the given identifier is marked as ignored.
	private func isIdentifierIgnored(_ identifier: String) -> Bool {
		return self.ignoredAppIdentifiers.contains(identifier)
	}
	
	/// Sets the ignored state of the given app.
	func setIgnoredState(_ ignored: Bool, for app: App) {
		var ignoredApps = self.ignoredAppIdentifiers
		
		if ignored {
			ignoredApps.insert(app.bundleIdentifier)
		} else {
			ignoredApps.remove(app.bundleIdentifier)
		}

		UserDefaults.standard.set(Array(ignoredApps), forKey: Self.IgnoredAppsKey)
		
		updateQueue.sync {
			self.update(app.with(ignoredState: ignored))
		}
	}
	
	/// Returns the identifiers of ignored apps.
	private var ignoredAppIdentifiers: Set<String> {
		return Set((UserDefaults.standard.array(forKey: Self.IgnoredAppsKey) as? [String]) ?? [])
	}

		
	// MARK: - Observer Handling
	
	/// A mapping of observers associated with apps.
	private var observers = [NSObject: ObserverHandler]()
	
	/// Adds the observer if it is not already registered.
	func addObserver(_ observer: NSObject, handler: @escaping ObserverHandler) {
		DispatchQueue.main.async {
			guard !self.observers.keys.contains(observer) else { return }
			self.observers[observer] = handler
				
			self.updateQueue.sync {
				// Call handler immediately to propagate initial state
				let apps = Array(self.apps)
				DispatchQueue.main.async {
					handler(apps)
				}
			}
		}
	}
	
	/// Removes the observer.
	func removeObserver(_ observer: NSObject) {
		DispatchQueue.main.async {
			self.observers.removeValue(forKey: observer)
		}
	}
		
	/// Notifies observers about state changes.
	private func notifyObservers(_ apps: [App]) {
		DispatchQueue.main.async {
			self.observers.forEach { (key: NSObject, handler: ObserverHandler) in
				handler(apps)
			}
		}
	}
		
}
