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
	typealias UpdateCheckerCompletionBlock = ((AppBundle) -> Void)
	
	/// Initializes the operation. May return nil if the app at the given URL can't be checked using the given update checker operation.
	init?(withAppURL appURL: URL, version: String, buildNumber: String, completionBlock: @escaping UpdateCheckerCompletionBlock)

}
