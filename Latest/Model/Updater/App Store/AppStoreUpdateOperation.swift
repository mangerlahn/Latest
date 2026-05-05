//
//  AppStoreUpdateOperation.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import CommerceKit
import StoreFoundation

/// The operation updating Mac App Store apps.
class AppStoreUpdateOperation: UpdateOperation, @unchecked Sendable {

	/// The purchase associated with the to be updated app.
	private var purchase: SSPurchase!

	/// The observer that observes the Mac App Store updater.
	private var observerIdentifier: CKDownloadQueueObserver?
	
	/// The app-store identifier for the related app.
	private let itemIdentifier: UInt64
	
	private let installURL: URL
	
	private var installerPackageURL: URL?

	init(bundleIdentifier: String, installURL: URL, appIdentifier: App.Bundle.Identifier, appStoreIdentifier: UInt64) {
		self.installURL = installURL
		self.itemIdentifier = appStoreIdentifier
		super.init(bundleIdentifier: bundleIdentifier, appIdentifier: appIdentifier)
	}
	
	static func prepareForUpdates() throws(InstallHelperError) {
		// Framework can download and install apps automatically
		if requiresManualInstallation {
			try InstallHelper.verifyAvailability()
		}
	}
	
	fileprivate static let requiresManualInstallation: Bool = {
		let version = ProcessInfo.processInfo.operatingSystemVersion
		
		return switch version.majorVersion {
		case 14:
			ProcessInfo.processInfo.isOperatingSystemAtLeast(.init(majorVersion: 14, minorVersion: 8, patchVersion: 2))
		case 15:
			ProcessInfo.processInfo.isOperatingSystemAtLeast(.init(majorVersion: 15, minorVersion: 7, patchVersion: 2))
		default:
			ProcessInfo.processInfo.isOperatingSystemAtLeast(.init(majorVersion: 26, minorVersion: 1, patchVersion: 0))
		}
	}()
	
	
	// MARK: - Operation Overrides

	override func execute() {
		super.execute()
		
		// Construct purchase to receive update
		let purchase = SSPurchase(itemIdentifier: self.itemIdentifier, account: nil)
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
	
	override func cancel() {
		self.finish()
	}

	override func finish() {
		if let observerIdentifier = self.observerIdentifier {
			CKDownloadQueue.shared().remove(observerIdentifier)
		}

		super.finish()
	}

	
	// MARK: - Manual Installation
	
	/// Adds a link to the downloaded app store package to retrieve it at a later time.
	fileprivate static func snapshotAppStorePackage(at path: String) -> URL? {
		do {
			let packageURL = URL(fileURLWithPath: path)
			let fileManager = FileManager.default
			
			let hardLinkURL = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: packageURL, create: true).appending(path: packageURL.lastPathComponent, directoryHint: .notDirectory)
			try fileManager.linkItem(at: packageURL, to: hardLinkURL)
			
			return hardLinkURL
		} catch {
			return nil
		}
	}
}


// MARK: - Download Observer

extension AppStoreUpdateOperation: CKDownloadQueueObserver {

	func downloadQueue(_ downloadQueue: CKDownloadQueue!, statusChangedFor download: SSDownload!) {
		// Cancel download if the operation has been cancelled
		if self.isCancelled {
			download.cancel(withStoreClient: ISStoreClient(storeClientType: 0))
			self.finish()
			return
		}

		guard download.metadata.itemIdentifier == itemIdentifier, let status = download.status else {
			return
		}
		
		// Nothing left to do, we wait for the install failure
		guard self.installerPackageURL == nil else {
			return
		}
		
		if Self.requiresManualInstallation && status.percentComplete >= 0.8 {
			// Keep the installer alive by linking to it. Manual installation will follow once the automatic one failed.
			self.progressState = .extracting(progress: 0.2)
			self.installerPackageURL = Self.snapshotAppStorePackage(at: download.primaryAsset.downloadPath)
			self.progressState = .extracting(progress: 0.7)
		} else {
			switch status.activePhase.phaseType {
			case 0:
				self.progressState = .downloading(loadedSize: Int64(status.activePhase.progressValue), totalSize: Int64(status.activePhase.totalProgressValue))
			case 1:
				self.progressState = .extracting(progress: Double(status.activePhase.progressValue) / Double(status.activePhase.totalProgressValue))
			default:
				self.progressState = .initializing
			}
		}
	}

	func downloadQueue(_ downloadQueue: CKDownloadQueue!, changedWithRemoval download: SSDownload!) {
		guard download.metadata.itemIdentifier == self.purchase.itemIdentifier, let status = download.status else {
			return
		}

		// Installed successfully
		guard status.isFailed else {
			self.finish()
			return
		}
		
		// No manual installation possible, abort with error
		guard let installerPackageURL, let receiptData = download.metadata.receiptData, let bundle = Bundle(identifier: bundleIdentifier), let receiptURL = bundle.appStoreReceiptURL else {
			self.finish(with: status.error)
			return
		}
		
		Task { [weak self] in
			guard let self, !self.isCancelled else {
				self?.finish()
				return
			}
			
			self.progressState = .installing
			
			do {
				try await InstallHelper.shared.installPackage(at: installerPackageURL, targetURL: bundle.bundlePath, receiptData: receiptData, receiptURL: receiptURL)
				self.finish()
			} catch {
				self.finish(with: error)
			}
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
	convenience init(itemIdentifier: UInt64, account: ISStoreAccount?) {
		self.init()

		let parameters: [String: Any] = [
			"productType": "C",
			"price": 0,
			"salableAdamId": itemIdentifier,
			"pg": "default",
			"appExtVrsId": 0,

			// is redownload, use existing functionality
			"pricingParameters": "STDRDL"
		]

		buyParameters =
			parameters.map { key, value in
				"\(key)=\(value)"
			}
			.joined(separator: "&")

		if let account = account {
			accountIdentifier = account.dsID
			appleID = account.identifier
		}

		let downloadMetadata = SSDownloadMetadata()
		downloadMetadata.kind = "software"
		downloadMetadata.itemIdentifier = itemIdentifier

		self.downloadMetadata = downloadMetadata
		self.itemIdentifier = itemIdentifier
	}
}

extension SSDownloadMetadata {
	/// Returns the app store receipt from the metadata.
	var receiptData: Data? {
		dictionary?["app-receipt"] as? Data
	}
}
