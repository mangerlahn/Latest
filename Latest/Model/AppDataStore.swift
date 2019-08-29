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
	
	enum Entry {
		case app(AppBundle)
		case section(Section)
	}
	
	enum Section {
		case updateAvailable
		case installed
	}
	
	private(set) var filteredApps = [Entry]()
	
	private(set) var apps = Set<AppBundle>()
	
//	/// Holds the apps
//	private var _rawData = [AppBundle]()
//	private var _filteredData: [AppBundle]?
//    
//	/// Convenience Accessor to the data store
//	fileprivate var data: [AppBundle] {
//		return self._filteredData ?? self._rawData
//	}
//    
    /// Flag indicating if all apps are presented
	var showInstalledUpdates = false {
		didSet {
			self.filterApps()
		}
	}
	
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
	
	private func filterApps() {
		var visibleApps = self.apps
		
		// Filter installed updates
		if !self.showInstalledUpdates {
			visibleApps = visibleApps.filter({ $0.updateAvailable })
		}
		
		// Apply filter query
		if let filterQuery = self.filterQuery {
			visibleApps = visibleApps.filter({ $0.name.lowercased().contains(filterQuery) })
		}
		
		// Sort apps
		self.filteredApps = visibleApps.sorted(by: { (app1, app2) -> Bool in
			if app1.updateAvailable != app2.updateAvailable {
				return app1.updateAvailable
			}
			
			return app1.name.lowercased() < app2.name.lowercased()
		}).map({ Entry.app($0) })
		
		// Add sections
		if self.showInstalledUpdates {
			if self.apps.count > self.countOfAvailableUpdates {
				self.filteredApps.insert(.section(.installed), at: self.countOfAvailableUpdates)
			}

			if self.countOfAvailableUpdates > 0 {
				self.filteredApps.insert(.section(.updateAvailable), at: 0)
			}
		}
		
		self.notifyObservers()
	}
	
	/// The cached count of apps with updates available
	private(set) var countOfAvailableUpdates: Int = 0
	
    /// Adds a new app to the collection
	func update(_ app: AppBundle) {
		if let oldApp = self.apps.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
			self.apps.remove(oldApp)
			self.pendingApps?.remove(oldApp)
			
			self.countOfAvailableUpdates -= oldApp.updateAvailable ? 1 : 0
		}
		
        self.apps.insert(app)
		
		self.countOfAvailableUpdates += app.updateAvailable ? 1 : 0
    }
	
	func app(at index: Int) -> AppBundle? {
		if case .app(let app) = self.filteredApps[index] {
			return app
		}
		
		return nil
	}
	
	
	// MARK: - Update Process
	
	private var pendingApps: Set<AppBundle>?
	
	func beginUpdates() {
		// Set our current state as pending
		self.pendingApps = self.apps
	}
	
	func endUpdates() {
		guard let pendingApps = self.pendingApps else { return }
		
		// Remove all apps that have not been updated
		self.apps.subtract(pendingApps)
		self.pendingApps = nil
		
		self.countOfAvailableUpdates = self.apps.filter({ $0.updateAvailable }).count
		self.filterApps()
	}
	
	
	// MARK: - Observer Handling
	
	/// The handler for notifying observers about changes to the update state.
	typealias ObserverHandler = () -> Void

	/// A mapping of observers assotiated with apps.
	private var observers = [NSObject: ObserverHandler]()
	
	/// Adds the observer if it is not already registered.
	func addObserver(_ observer: NSObject, handler: @escaping ObserverHandler) {
		guard !self.observers.keys.contains(observer) else { return }
		self.observers[observer] = handler
		
		// Call handler immediately to propagate initial state
		handler()
	}
	
	/// Remvoes the observer.
	func removeObserver(_ observer: NSObject, for app: AppBundle) {
		self.observers.removeValue(forKey: observer)
	}
		
	/// Notifies observers about state changes.
	private func notifyObservers() {
		DispatchQueue.main.async {
			self.observers.forEach { (key: NSObject, handler: ObserverHandler) in
				handler()
			}
		}
	}

//
//    /// Returns the relative index of the element. This index may not reflect the internal position of the app due to section offsets
//    func index(of element: Element) -> Index? {
//        guard element.updateAvailable || self.showInstalledUpdates, let index = self.data.firstIndex(of: element) else { return nil }
//        
//        return self.align(index)
//    }
//    
//    /// Removes the app from the collection
//    @discardableResult
//    mutating func remove(_ appBundle: AppBundle) -> Int? {
//        guard let index = self.data.firstIndex(where: { $0 == appBundle }) else { return nil }
//        let returnedIndex = self.index(of: appBundle)
//        
//        self._rawData.remove(at: index)
//		self.updateFilteredApps()
//        
//        return returnedIndex
//    }
//	
//	/// Updates the contents of the given app
//	@discardableResult
//	mutating func update(_ app: AppBundle) -> Int? {
//		guard let index = self.data.firstIndex(where: { $0 == app }) else { return nil }
//		self._rawData.remove(at: index)
//		
//		self._rawData.append(app)
//		self.sortApps()
//		self.updateFilteredApps()
//		
//		return self.index(of: app)
//	}
//    
    /// Returns whether there is a section at the given index
    func isSectionHeader(at index: Int) -> Bool {
		if case .section(_) = self.filteredApps[index] {
			return true
		}
		
		return false
    }
//    
//    /// This method counts all available updates. It assumes that the array is sorted with all updates at the beginning
//    private mutating func updateCountOfAvailableUpdates() {
//        self.countOfAvailableUpdates = self.data.firstIndex(where: { !$0.updateAvailable }) ?? self.data.count
//    }
//    
//    /// Aligns the index based on the section headers
//    private func align(_ index: Int) -> Int {
//        var index = index
//        
//        if self.showInstalledUpdates {
//            index += self.countOfAvailableUpdates < index ? 2 : 1
//        }
//        
//        if self.isSectionHeader(at: index) {
//            index += 1
//        }
//        
//        return index
//    }
    
}

//
//// MARK: - Filtering
//extension AppCollection {
//	
//	mutating func sortApps() {
//        self._rawData.sort { (bundle1, bundle2) -> Bool in
//            if bundle1.updateAvailable != bundle2.updateAvailable {
//                return bundle1.updateAvailable
//            }
//            
//            return bundle1.name.lowercased() < bundle2.name.lowercased()
//        }
//	}
//	
//	mutating func updateFilteredApps() {
//		defer {
//			self.updateCountOfAvailableUpdates()
//		}
//		
//		guard let filterQuery = self.filterQuery?.lowercased() else {
//			self._filteredData = nil
//			return
//		}
//		
//		// Filter all available apps using the given query
//		self._filteredData = self._rawData.filter({ $0.name.lowercased().contains(filterQuery) })
//	}
	
//}
