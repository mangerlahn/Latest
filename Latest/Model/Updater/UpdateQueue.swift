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
	
	override func addOperation(_ op: Operation) {
		// Abort if the operation is of an unknown type
		guard let operation = op as? UpdateOperation, let updateOperations = self.operations as? [UpdateOperation] else {
			fatalError("Added unknown operation \(op.self) to update queue.")
		}
		
		// Abort if the app is already in the queue
		let identifier = operation.app.bundleIdentifier
		if let _ = updateOperations.first(where: { $0.app.bundleIdentifier == identifier }) {
			return
		}
	
		super.addOperation(op)
	}
}
