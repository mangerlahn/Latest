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
	
	/// Cancels the update operation for the given app.
	func cancelUpdate(for app: AppBundle) {
		guard let operation = self.operation(for: app) else { return }
		operation.cancel()
	}
	
	/// Whether the queue contains an update operation for the given app.
	func contains(_ app: AppBundle) -> Bool {
		return self.operation(for: app) != nil
	}
	
	override func addOperation(_ op: Operation) {
		// Abort if the operation is of an unknown type
		guard let operation = op as? UpdateOperation else {
			fatalError("Added unknown operation \(op.self) to update queue.")
		}
		
		// Abort if the app is already in the queue
		if !self.contains(operation.app) {
			super.addOperation(op)
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
