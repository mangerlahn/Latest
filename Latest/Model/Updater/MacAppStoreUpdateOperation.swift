//
//  MacAppStoreUpdateOperation.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import CommerceKit
import StoreFoundation

class MacAppStoreUpdateOperation: UpdateOperation {
	
	init(app: MacAppStoreAppBundle, progressHandler: @escaping UpdateOperation.ProgressHandler, completionHandler: @escaping UpdateOperation.CompletionHandler) {
		super.init(app: app, progressHandler: progressHandler, completionHandler: completionHandler)
	}
	
	var purchase: SSPurchase!
	
	var observerIdentifier: CKDownloadQueueObserver?
	
	override func execute() {
		super.execute()
		
		let app = self.app as! MacAppStoreAppBundle
		
		// Verify update is available
		guard let update = app.updateInformation else {
			// TODO: Finish with error `noUpdate`
			self.cancel()
			return
		}
		
		// Verify user is signed in
		guard let account = ISStoreAccount.primaryAccount as? ISStoreAccount else {
			// TODO: Finish with error `notSignedIn`
			self.cancel()
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
				// TODO: Finish with error `noUpdateFound`
				self.cancel()
			}
		}
	}
	
	override func finish(with error: Error) {
		self.removeObserver()
		super.finish(with: error)
	}
	
	override func finish() {
		self.removeObserver()
		super.finish()
	}
	
	private func removeObserver() {
		if let observerIdentifier = self.observerIdentifier {
			CKDownloadQueue.shared().remove(observerIdentifier)
		}
	}
	
}
	// MARK: - Download Observer
	
extension MacAppStoreUpdateOperation: CKDownloadQueueObserver {

	func downloadQueue(_ downloadQueue: CKDownloadQueue!, statusChangedFor download: SSDownload!) {
		guard download.metadata.itemIdentifier == self.purchase.itemIdentifier,
			let status = download.status else {
				return
		}
		
		if status.isFailed || status.isCancelled {
			downloadQueue.removeDownload(withItemIdentifier: download.metadata.itemIdentifier)
		} else {
			switch status.activePhase.phaseType {
			case 0:
				progressHandler(.downloading(Double(status.percentComplete)))
			case 1:
				progressHandler(.installing)
			default:
				progressHandler(.initializing)
			}
		}
	}
	
	func downloadQueue(_ downloadQueue: CKDownloadQueue!, changedWithAddition download: SSDownload!) {}
	func downloadQueue(_ downloadQueue: CKDownloadQueue!, changedWithRemoval download: SSDownload!) {
		guard download.metadata.itemIdentifier == purchase.itemIdentifier,
			let status = download.status else {
				return
		}
		
		if status.isFailed {
			self.finish(with: status.error)
		} else if status.isCancelled {
			self.finish()
		} else {
			self.finish()
		}
	}
	
}
