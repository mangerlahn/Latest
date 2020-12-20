//
//  UpdateQueue.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Foundation

/// The queue where update operations are scheduled on.
class UpdateQueue: OperationQueue {
	
	// MARK: - Initialization
	private override init() {
		super.init()
		
		self.maxConcurrentOperationCount = 3
	}
	
	/// The shared instance of the queue.
	static let shared = UpdateQueue()
	
	
	// MARK: - Public Methods
	
	/// The handler forwarding the current progress state.
	typealias ProgressHandler = (_: AppBundle) -> Void
	
	/// Cancels the update operation for the given app.
	func cancelUpdate(for app: AppBundle) {
		guard let operation = self.operation(for: app) else { return }
		operation.cancel()
	}
	
	/// Whether the queue contains an update operation for the given app.
	func contains(_ app: AppBundle) -> Bool {
		return self.operation(for: app) != nil
	}
	
	/// Returns the state for a given app.
	func state(for app: AppBundle) -> UpdateOperation.ProgressState {
		return self.operation(for: app)?.progressState ?? .none
	}
	
	override func addOperation(_ op: Operation) {
		// Abort if the operation is of an unknown type
		guard let operation = op as? UpdateOperation else {
			assertionFailure("Added unknown operation \(op.self) to update queue.")
			return
		}
		
		// Abort if the app is already in the queue
		if !self.contains(operation.app) {
			super.addOperation(op)
			
			operation.progressHandler = { app in
				self.notifyObservers(for: app)
			}
		}
	}
	
	
	// MARK: - Observer Handling
	
	/// The handler for notifying observers about changes to the update state.
	typealias ObserverHandler = (_: UpdateOperation.ProgressState) -> Void

	/// A mapping of observers assotiated with apps.
	private var observers = [String : [NSObject: ObserverHandler]]()
	
	/// Adds the observer if it is not already registered.
	func addObserver(_ observer: NSObject, to app: AppBundle, handler: @escaping ObserverHandler) {
		var observers = self.observers[app.bundleIdentifier] ?? [:]
		
		// Only add the observer, if it is not already installed.
		guard observers[observer] == nil else {
			return
		}
		
		observers[observer] = handler
		
		// Call handler immediately to propagate initial state
		handler(self.state(for: app))
		
		// Update observers
		self.observers[app.bundleIdentifier] = observers
	}
	
	/// Remvoes the observer.
	func removeObserver(_ observer: NSObject, for app: AppBundle) {
		self.observers[app.bundleIdentifier]?.removeValue(forKey: observer)
	}
		
	/// Notifies observers about state changes.
	private func notifyObservers(for app: AppBundle) {
		let state = self.state(for: app)
		
		DispatchQueue.main.async {
			self.observers[app.bundleIdentifier]?.forEach { (key: NSObject, handler: UpdateQueue.ObserverHandler) in
				handler(state)
			}
		}
	}
	
	
	// MARK: - Helper
	
	/// Returns the operation for the given app.
	private func operation(for app: AppBundle) -> UpdateOperation? {
		guard let updateOperations = self.operations as? [UpdateOperation] else {
			fatalError("Unknown operations in update queue")
		}
				
		let identifier = app.bundleIdentifier
		return updateOperations.first(where: { $0.app.bundleIdentifier == identifier })
	}
		
}
