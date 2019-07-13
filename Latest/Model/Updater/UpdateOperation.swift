//
//  UpdateOperation.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Foundation

class UpdateOperation: StatefulOperation {
	
	enum ProgressState {
		case none
		case pending
		case initializing
		case downloading(Double)
		case installing
	}
	
	typealias ProgressHandler = (_: ProgressState) -> Void
	
	typealias CompletionHandler = (_: Error?) -> Void
	
	let app: AppBundle
	
	let progressHandler: UpdateOperation.ProgressHandler
	
	let completionHandler: UpdateOperation.CompletionHandler
	
	init(app: AppBundle, progressHandler: @escaping UpdateOperation.ProgressHandler, completionHandler: @escaping UpdateOperation.CompletionHandler) {
		self.app = app
		self.progressHandler = progressHandler
		self.completionHandler = completionHandler
		
		self.progressHandler(.pending)
	}
	
	override func execute() {
		self.progressHandler(.initializing)
	}
	
	override func finish(with error: Error) {
		self.progressHandler(.none)
		self.completionHandler(error)
		super.finish(with: error)
	}
	
	override func finish() {
		self.progressHandler(.none)
		self.completionHandler(nil)
		super.finish()
	}
	
}
