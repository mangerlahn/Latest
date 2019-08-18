//
//  UpdateProgress.swift
//  Latest
//
//  Created by Max Langer on 18.08.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Foundation

/// Encapsulates information about an update.
struct UpdateProgress {
	
	/// The current update state.
	var state: UpdateOperation.ProgressState = .none {
		didSet {
			self.notifyObservers()
		}
	}
	
	
	// MARK: - Observer Handling
	
	/// The handler for notifying observers about changes to the update state.
	typealias ObserverHandler = (_: UpdateProgress) -> Void

	/// A mapping of observers of this update progress.
	private var observers = [NSObject: ObserverHandler]()
	
	/// Adds the observer if it is not already registered.
	mutating func addObserver(_ observer: NSObject, handler: @escaping ObserverHandler) {
		// Only add the observer, if it is not already installed.
		guard self.observers[observer] == nil else {
			return
		}
		
		self.observers[observer] = handler
		
		// Call handler immediately to propagate initial state
		handler(self)
	}
	
	/// Remvoes the observer.
	mutating func removeObserver(_ observer: NSObject) {
		self.observers.removeValue(forKey: observer)
	}
		
	/// Notifies observers about state changes.
	private func notifyObservers() {
		DispatchQueue.main.async {
			self.observers.forEach { (key: NSObject, handler: UpdateProgress.ObserverHandler) in
				handler(self)
			}
		}
	}
	
}
