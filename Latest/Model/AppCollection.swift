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
struct AppCollection {
	
	/// Holds the apps
	private var _rawData = [AppBundle]()
	private var _filteredData: [AppBundle]?
    
	/// Convenience Accessor to the data store
	fileprivate var data: [AppBundle] {
		return self._filteredData ?? self._rawData
	}
    
    /// Flag indicating if all apps are presented
    var showInstalledUpdates = false
	
	/// The query after which apps can be filtered
	var filterQuery: String? {
		didSet {
			if self.filterQuery?.isEmpty ?? false {
				self.filterQuery = nil
			}
			
			self.updateFilteredApps()
		}
	}

    /// The indexes of the sections as well as installed apps
    var indexesOfInstalledApps: IndexSet {
        // The first section header
        var indexSet = IndexSet(integer: 0)
        
        // All installed apps including the second header
        indexSet.insert(integersIn: (self.countOfAvailableUpdates + 1)..<(self.data.count + 2))
        
        return indexSet
    }
    
    /// The number of apps available
    var count: Int {
        if !self.showInstalledUpdates {
            return self.data.filter({ $0.updateAvailable }).count
        }
		
		// Append header row count
        return self.data.count + 2
    }
    
    /// The cached value of the count of apps with updates available
    private(set) var countOfAvailableUpdates: Int = 0
    
    /// Adds a new app to the collection
    mutating func append(_ element: Element) {
        self._rawData.append(element)
        self._rawData.sort { (bundle1, bundle2) -> Bool in
            if bundle1.updateAvailable != bundle2.updateAvailable {
                return bundle1.updateAvailable
            }
            
            return bundle1.name.lowercased() < bundle2.name.lowercased()
        }
		
		self.updateFilteredApps()
    }

    /// Returns the relative index of the element. This index may not reflect the internal position of the app due to section offsets
    func index(of element: Element) -> Index? {
        guard element.updateAvailable || self.showInstalledUpdates, let index = self.data.firstIndex(of: element) else { return nil }
        
        return self.align(index)
    }
    
    /// Removes the app from the collection
    @discardableResult
    mutating func remove(_ appBundle: AppBundle) -> Int? {
        guard let index = self.data.firstIndex(where: { $0 == appBundle }) else { return nil }
        let returnedIndex = self.index(of: appBundle)
        
        self._rawData.remove(at: index)
		self.updateFilteredApps()
        
        return returnedIndex
    }
    
    /// Returns whether there is a section at the given index
    func isSectionHeader(at index: Int) -> Bool {
        guard self.showInstalledUpdates else { return false }
        
        return [0, self.countOfAvailableUpdates + 1].contains(index)
    }
    
    /// This method counts all available updates. It assumes that the array is sorted with all updates at the beginning
    private mutating func updateCountOfAvailableUpdates() {
        self.countOfAvailableUpdates = self.data.firstIndex(where: { !$0.updateAvailable }) ?? self.data.count
    }
    
    /// Aligns the index based on the section headers
    private func align(_ index: Int) -> Int {
        var index = index
        
        if self.showInstalledUpdates {
            index += self.countOfAvailableUpdates < index ? 2 : 1
        }
        
        if self.isSectionHeader(at: index) {
            index += 1
        }
        
        return index
    }
    
}

extension AppCollection: Collection {
    
    typealias DataType = [AppBundle]
    
    typealias Index = DataType.Index
    typealias Element = DataType.Element
    typealias Iterator = DataType.Iterator
    
    var startIndex: Index { return self.data.startIndex }
    var endIndex: Index { return self.data.endIndex }
    
    subscript(position: Index) -> Element {
        var position = position
        
        if self.showInstalledUpdates {
            position -= self.countOfAvailableUpdates < position ? 2 : 1 // Remove first row
        }
        
        return self.data[Swift.max(position, 0)]
    }
    
    func makeIterator() -> Iterator {
        return self.data.makeIterator()
    }
    
    // Method that returns the next index when iterating
    func index(after i: Index) -> Index {
        return self.data.index(after: i)
    }
    
    func firstIndex(where predicate: (AppCollection.DataType.Element) throws -> Bool) rethrows -> AppCollection.DataType.Index? {
        guard let appIndex = try? self.data.firstIndex(where: predicate), var index = appIndex else { return nil }
        
        index = self.align(index)
        
        return index
    }
    
}

// MARK: - Filtering
extension AppCollection {
	
	mutating func updateFilteredApps() {
		defer {
			self.updateCountOfAvailableUpdates()
		}
		
		guard let filterQuery = self.filterQuery?.lowercased() else {
			self._filteredData = nil
			return
		}
		
		// Filter all available apps using the given query
		self._filteredData = self._rawData.filter({ $0.name.lowercased().contains(filterQuery) })
	}
	
}
