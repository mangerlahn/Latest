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
class MacAppStoreUpdateOperation: UpdateOperation, @unchecked Sendable {

	/// The purchase associated with the to be updated app.
	private var purchase: SSPurchase!

	/// The observer that observes the Mac App Store updater.
	private var observerIdentifier: CKDownloadQueueObserver?
	
	/// The app-store identifier for the related app.
	private var itemIdentifier: UInt64

	init(bundleIdentifier: String, appIdentifier: App.Bundle.Identifier, appStoreIdentifier: UInt64) {
		self.itemIdentifier = appStoreIdentifier
		super.init(bundleIdentifier: bundleIdentifier, appIdentifier: appIdentifier)
	}
	
	
	// MARK: - Operation Overrides

	override func execute() {
		super.execute()

		// Verify user is signed in
		var storeAccount: ISStoreAccount?
		if #unavailable(macOS 12) {
			// Monterey obscured the user's account information, but still allows
			// redownloads without passing it to SSPurchase.
			// https://github.com/mas-cli/mas/issues/417
			guard let account = ISStoreAccount.primaryAccount else {
				self.finish(with: LatestError.notSignedInToAppStore)
				return
			}

			storeAccount = account
		}
		
		// Construct purchase to receive update
		let purchase = SSPurchase(itemIdentifier: self.itemIdentifier, account: storeAccount)
		CKPurchaseController.shared().perform(purchase, withOptions: 0) { [weak self] purchase, _, error, response in
			guard let self = self else { return }

			if let error = error {
				self.finish(with: error)
				return
			}

			if let downloads = response?.downloads, downloads.count > 0, let purchase = purchase {
				self.purchase = purchase
				self.observerIdentifier = CKDownloadQueue.shared().add(self)
			} else {
				self.finish(with: LatestError.updateInfoUnavailable)
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
			self.progressState = .extracting(progress: Double(status.activePhase.progressValue) / Double(status.activePhase.totalProgressValue))
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

private extension ISStoreAccount {
	static var primaryAccount: ISStoreAccount? {
		var account: ISStoreAccount?
		
		let group = DispatchGroup()
		group.enter()
		
		let accountService: ISAccountService = ISServiceProxy.genericShared().accountService
		accountService.primaryAccount { (storeAccount: ISStoreAccount) in
			account = storeAccount
			group.leave()
		}
		
		_ = group.wait(timeout: .now() + 30)
		
		return account
	}
}

private extension SSPurchase {
	convenience init(itemIdentifier: UInt64, account: ISStoreAccount?, purchase: Bool = false) {
		self.init()

		var parameters: [String: Any] = [
			"productType": "C",
			"price": 0,
			"salableAdamId": itemIdentifier,
			"pg": "default",
			"appExtVrsId": 0,
		]

		if purchase {
			parameters["macappinstalledconfirmed"] = 1
			parameters["pricingParameters"] = "STDQ"

		} else {
			// is redownload, use existing functionality
			parameters["pricingParameters"] = "STDRDL"
		}

		buyParameters =
			parameters.map { key, value in
				"\(key)=\(value)"
			}
			.joined(separator: "&")

		if let account = account {
			accountIdentifier = account.dsID
			appleID = account.identifier
		}

		// Not sure if this is needed, but lets use it here.
		if purchase {
			isRedownload = false
		}

		let downloadMetadata = SSDownloadMetadata()
		downloadMetadata.kind = "software"
		downloadMetadata.itemIdentifier = itemIdentifier

		self.downloadMetadata = downloadMetadata
		self.itemIdentifier = itemIdentifier
	}
}
