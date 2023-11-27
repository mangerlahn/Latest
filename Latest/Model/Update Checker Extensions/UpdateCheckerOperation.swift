//
//  UpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

/// A protocol that defines how a update checker operation should be structured
protocol UpdateCheckerOperation: StatefulOperation {
	
	/// The completion block called after the update check completes
	typealias UpdateCheckerCompletionBlock = ((Result<App.Update, Error>) -> Void)
	
	/// Initializes the operation. May return nil if the app at the given URL can't be checked using the given update checker operation.
	init(with bundle: App.Bundle, repository: UpdateRepository?, completionBlock: @escaping UpdateCheckerCompletionBlock)

	/// Returns whether the operation can perform an update check for the app at the given url.
	static func canPerformUpdateCheck(forAppAt url: URL) -> Bool
	
	/// The type of source this operation can check.
	static var sourceType: App.Source { get }
	
}
