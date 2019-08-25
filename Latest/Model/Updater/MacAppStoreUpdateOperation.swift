//
//  MacAppStoreUpdateOperation.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import CommerceKit
import StoreFoundation

/// The operation updating Mac App Store apps.
class MacAppStoreUpdateOperation: UpdateOperation {
	
	/// Initializes the operation with the given Mac App Store app and progress handler.
	init(app: MacAppStoreAppBundle) {
		super.init(app: app)
	}
	
	/// The purchase associated with the to be updated app.
	private var purchase: SSPurchase!
	
	/// The observer that observes the Mac App Store updater.
	private var observerIdentifier: CKDownloadQueueObserver?
	
	
	// MARK: - Operation Overrides
	
	override func execute() {
		super.execute()
		
		let app = self.app as! MacAppStoreAppBundle
		
		// Verify update is available
		guard let update = app.updateInformation else {
			self.finish(with: NSError.noUpdate)
			return
		}
		
		// Verify user is signed in
		guard let account = ISStoreAccount.primaryAccount as? ISStoreAccount else {
			self.finish(with: NSError.notSignedIn)
			return
		}
		
		// Construct purchase to receive update
		let purchase = SSPurchase(adamId: update.itemIdentifier.uint64Value, account: account)
		
		purchase.perform { [weak self] purchase, _, error, response in
			guard let self = self else { return }
			
			if let error = error {
				self.finish(with: error)
				return
			}
			
			if let downloads = response?.downloads, downloads.count > 0, let purchase = purchase {
				self.purchase = purchase
				self.observerIdentifier = CKDownloadQueue.shared().add(self)
			} else {
				self.finish(with: NSError.noUpdate)
			}
		}
	}
		
	override func finish() {
		if let observerIdentifier = self.observerIdentifier {
			CKDownloadQueue.shared().remove(observerIdentifier)
		}

		super.finish()
	}
	
}

// MARK: - Download Observer

extension MacAppStoreUpdateOperation: CKDownloadQueueObserver {

	func downloadQueue(_ downloadQueue: CKDownloadQueue!, statusChangedFor download: SSDownload!) {
		// Cancel download if the operation has been cancelled
		if self.isCancelled {
			download.cancel(withStoreClient: ISStoreClient(storeClientType: 0))
			self.finish()
			return
		}
		
		guard download.metadata.itemIdentifier == self.purchase.itemIdentifier,
			let status = download.status else {
				return
		}
		
		guard !status.isFailed && !status.isCancelled else {
			downloadQueue.removeDownload(withItemIdentifier: download.metadata.itemIdentifier)
			self.finish(with: status.error)
			return
		}
		
		switch status.activePhase.phaseType {
		case 0:
			self.progressState = .downloading(loadedSize: Int64(status.activePhase.progressValue), totalSize: Int64(status.activePhase.totalProgressValue))
		case 1:
			self.progressState = .installing
		default:
			self.progressState = .initializing
		}
	}
	
	func downloadQueue(_ downloadQueue: CKDownloadQueue!, changedWithRemoval download: SSDownload!) {
		guard download.metadata.itemIdentifier == self.purchase.itemIdentifier, let status = download.status else {
			return
		}
		
		// Cancel operation.
		if status.isFailed {
			self.finish(with: status.error)
		} else {
			self.finish()
		}
	}
	
	func downloadQueue(_ downloadQueue: CKDownloadQueue!, changedWithAddition download: SSDownload!) {}
	
}

/// Error conveniences
private extension NSError {
	
	/// The user is not signed in into the app store account with which the app was purchaised.
	static var notSignedIn: NSError {
		let description = NSLocalizedString("Please sign in to the Mac App Store to update this app.", comment: "Error description when no update was found for a particular app.")
		return NSError(latestErrorWithCode: NSError.LatestErrorCodes.notSignedIn, localizedDescription: description)
	}

}

private extension NSError.LatestErrorCodes {
	
	static let notSignedIn = 1
	
}
