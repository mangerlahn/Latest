//
//  UpdateOperation.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Foundation

/// The abstract update operation used for updating apps.
class UpdateOperation: StatefulOperation {
	
	/// Encapsulates different states that may be active during the update process.
	enum ProgressState {
		/// No update is ocurring at the moment.
		case none
		
		/// The update is currently waiting to be executed. This may happen due to external constraints like the Mac App Store update queue.
		case pending
		
		/// The download is currently initializing. This may be fetching update information from a server.
		case initializing
		
		/// The new version is currently downloading. Loaded size defines the already downloaded bytes. Total size defines the final size of the download.
		case downloading(loadedSize: Int64, totalSize: Int64)
		
		/// The update is being extracted. The extraction progress is given.
		case extracting(progress: Double)
		
		/// The update is currently installing.
		case installing
		
		/// An error occurred during updating.
		case error(Error)
		
		/// The update is currently being cancelled.
		case cancelling
	}
	
	/// The app that is updated by this operation.
	let app: AppBundle
	
	/// The handler forwarding the current progress state.
	var progressHandler: UpdateQueue.ProgressHandler?
	
		/// The current update state.
	var progressState: UpdateOperation.ProgressState = .pending {
		didSet {
			self.progressHandler?(self.app)
		}
	}

	
	/// Initializes the operation with the given app and progress handler.
	init(app: AppBundle) {
		self.app = app
	}
	
	
	// MARK: - Operation subclassing
	
	override func execute() {
		self.progressState = .initializing
	}
	
	override func cancel() {
		super.cancel()
		self.progressState = .cancelling
	}
		
	override func finish() {
		if let error = self.error {
			self.progressState = .error(error)
		} else {
			self.app.completeUpdate()
			self.progressState = .none
		}
		
		super.finish()
	}
	
}

// Error conveniences.
extension NSError {

	/// No update was found for this app.
	static var noUpdate: NSError {
		let description = NSLocalizedString("No update was found for this app.", comment: "Error description when no update was found for a particular app.")
		return NSError(latestErrorWithCode: NSError.LatestErrorCodes.noUpdate, localizedDescription: description)
	}
	
}

extension NSError.LatestErrorCodes {

	static let noUpdate = 0
	
}
