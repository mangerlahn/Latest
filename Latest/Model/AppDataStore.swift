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
	private let persistenceQueue = DispatchQueue(label: "AppDataStore.persistence", qos: .utility)
	
	
	init() {
		self.updateScheduler = DispatchSource.makeUserDataAddSource(queue: .global())
		self.setupScheduler()
		self.apps = self.loadCachedApps()
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
			self.persist(apps: self.apps)
		}
	}
	
	/// A subset of apps that can be updated. Ignored apps are not part of this list.
	var updatableApps: [App] {
		updateQueue.sync {
			return self.apps.filter({ $0.updateAvailable && $0.canPerformUpdate && $0.usesBuiltInUpdater && !$0.isIgnored })
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

	private struct CachedBundle: Codable {
		let versionNumber: String?
		let buildNumber: String?
		let name: String
		let bundleIdentifier: String
		let filePath: String
		let source: String
		
		init(bundle: App.Bundle) {
			self.versionNumber = bundle.version.versionNumber
			self.buildNumber = bundle.version.buildNumber
			self.name = bundle.name
			self.bundleIdentifier = bundle.bundleIdentifier
			self.filePath = bundle.fileURL.path
			self.source = bundle.source.rawValue
		}
		
		var bundle: App.Bundle? {
			guard let source = App.Source(rawValue: source) else { return nil }
			
			return App.Bundle(
				version: Version(versionNumber: versionNumber, buildNumber: buildNumber),
				name: name,
				bundleIdentifier: bundleIdentifier,
				fileURL: URL(fileURLWithPath: filePath),
				source: source
			)
		}
	}
	
	private struct CachedUpdate: Codable {
		let versionNumber: String?
		let buildNumber: String?
		let minimumOSVersion: String?
		let source: String
		let date: Date?
		
		init(update: App.Update) {
			self.versionNumber = update.remoteVersion.versionNumber
			self.buildNumber = update.remoteVersion.buildNumber
			if let minimumOSVersion = update.minimumOSVersion {
				self.minimumOSVersion = "\(minimumOSVersion.majorVersion).\(minimumOSVersion.minorVersion).\(minimumOSVersion.patchVersion)"
			} else {
				self.minimumOSVersion = nil
			}
			self.source = update.source.rawValue
			self.date = update.date
		}
		
		func update(for bundle: App.Bundle) -> App.Update? {
			guard let source = App.Source(rawValue: source) else { return nil }
			let minimumOSVersion = minimumOSVersion.flatMap { try? OperatingSystemVersion(string: $0) }
			
			return App.Update(
				app: bundle,
				remoteVersion: Version(versionNumber: versionNumber, buildNumber: buildNumber),
				minimumOSVersion: minimumOSVersion,
				source: source,
				date: date,
				releaseNotes: nil,
				updateAction: Self.cachedAction(for: source, bundle: bundle),
				isCached: true
			)
		}
		
		private static func cachedAction(for source: App.Source, bundle: App.Bundle) -> App.Update.Action {
			switch source {
			case .sparkle:
				return .builtIn(block: { app in
					UpdateQueue.shared.addOperation(SparkleUpdateOperation(bundleURL: app.fileURL, bundleIdentifier: app.bundleIdentifier, appIdentifier: app.identifier))
				})
			case .appStore:
				return .external(label: NSLocalizedString("AppStoreSource", comment: "The source name of apps loaded from the App Store."), block: { app in
					app.open()
				})
			case .homebrew:
				return .external(label: NSLocalizedString("HomebrewSource", comment: "The source name for apps checked via the Homebrew package manager."), block: { app in
					app.open()
				})
			case .none:
				return .external(label: bundle.name, block: { app in
					app.open()
				})
			}
		}
	}
	
	private struct CachedApp: Codable {
		let bundle: CachedBundle
		let update: CachedUpdate?
		let isIgnored: Bool
		
		init(app: App) {
			self.bundle = CachedBundle(bundle: app.bundle)
			self.update = app.cachedUpdate.map(CachedUpdate.init)
			self.isIgnored = app.isIgnored
		}
		
		var app: App? {
			guard let bundle = bundle.bundle else { return nil }
			let update = update?.update(for: bundle)
			return App(bundle: bundle, update: update.map(Result.success), isIgnored: isIgnored)
		}
	}
	
	private static var cacheURL: URL? {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
			.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Latest", isDirectory: true)
			.appendingPathComponent("AppBundles.json")
	}
	
	private func loadCachedApps() -> Set<App> {
		guard let cacheURL = Self.cacheURL,
			  let data = try? Data(contentsOf: cacheURL) else {
			return []
		}
		
		if let cachedApps = try? JSONDecoder().decode([CachedApp].self, from: data) {
			return Set(cachedApps.compactMap(\.app))
		}
		
		guard let cachedBundles = try? JSONDecoder().decode([CachedBundle].self, from: data) else {
			return []
		}
		
		return Set(cachedBundles.compactMap(\.bundle).map { bundle in
			App(bundle: bundle, update: nil, isIgnored: self.isIdentifierIgnored(bundle.bundleIdentifier))
		})
	}
	
	private func persist(apps: Set<App>) {
		let cachedApps = apps.map(CachedApp.init)
		
		persistenceQueue.async {
			guard let cacheURL = Self.cacheURL else { return }
			
			do {
				try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
				let data = try JSONEncoder().encode(cachedApps)
				try data.write(to: cacheURL, options: .atomic)
			} catch {
				()
			}
		}
	}
	
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
