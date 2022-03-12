//
//  MacAppStoreUpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

/// The operation for checking for updates for a Mac App Store app.
class UnsupportedUpdateCheckerOperation: StatefulOperation, UpdateCheckerOperation {
	
	static var sourceType: App.Bundle.Source {
		return .unsupported
	}
		
	static func canPerformUpdateCheck(forAppAt url: URL) -> Bool {
		return true
	}
	
	required init(with app: App.Bundle, completionBlock: @escaping UpdateCheckerCompletionBlock) {
		super.init()

		self.completionBlock = {
			completionBlock(.failure(LatestError.updateInfoNotFound))
		}
	}
	
	
	// MARK: - Operation

	override func execute() {
		// Nothing to check for, finish immediately
		self.finish()
	}
	
}
