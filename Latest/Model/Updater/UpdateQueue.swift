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
	
}
