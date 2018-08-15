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
struct AppCollection {
    
    /// Holds the apps
    fileprivate var data = [AppBundle]()
    
    /// Flag indicating if all apps are presented
    var showInstalledUpdates = false

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
        
        return self.data.count + 2
    }
    
    /// The cached value of the count of apps with updates available
    private(set) var countOfAvailableUpdates: Int = 0
    
    /// Adds a new app to the collection
    mutating func append(_ element: Element) {
        self.data.append(element)
        self.data.sort { (bundle1, bundle2) -> Bool in
            if bundle1.updateAvailable != bundle2.updateAvailable {
                return bundle1.updateAvailable
            }
            
            return bundle1.name < bundle2.name
        }
        
        self.updateCountOfAvailableUpdates()
    }

    /// Returns the relative index of the element. This index may not reflect the internal position of the app due to section offsets
    func index(of element: Element) -> Index? {
        guard element.updateAvailable || self.showInstalledUpdates, var index = self.data.firstIndex(of: element) else { return nil }
        
        if self.showInstalledUpdates {
            index += self.countOfAvailableUpdates < index ? 2 : 1
        }
        
        if self.isSectionHeader(at: index) {
            index += 1
        }
        
        return index
    }
    
    /// Removes the app from the collection
    @discardableResult
    mutating func remove(_ appBundle: AppBundle) -> Int? {
        guard let index = self.data.firstIndex(where: { $0 == appBundle }) else { return nil }
        
        self.data.remove(at: index)
        self.updateCountOfAvailableUpdates()
        
        return index
    }
    
    /// Returns whether there is a section at the given index
    func isSectionHeader(at index: Int) -> Bool {
        guard self.showInstalledUpdates else { return false }
        
        return [0, self.countOfAvailableUpdates + 1].contains(index)
    }
    
    // This method counts all available updates. It assumes that the array is sorted with all updates at the beginning
    private mutating func updateCountOfAvailableUpdates() {
        self.countOfAvailableUpdates = self.data.firstIndex(where: { !$0.updateAvailable }) ?? self.data.count
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
    
}
