//
//  UpdateQueue.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Foundation

class UpdateQueue: OperationQueue {
	
	private override init() {
		super.init()
		
		self.maxConcurrentOperationCount = 3
	}
	
	static let shared = UpdateQueue()
	
	func contains(_ app: AppBundle) -> Bool {
		guard let updateOperations = self.operations as? [UpdateOperation] else {
			fatalError("Unknown operations in update queue")
		}
		
		let identifier = app.bundleIdentifier
		return updateOperations.contains(where: { $0.app.bundleIdentifier == identifier })
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
}
