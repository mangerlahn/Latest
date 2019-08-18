//
//  SparkleUpdateOperation.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Sparkle

/// The operation updating Sparkle apps.
class SparkleUpdateOperation: UpdateOperation {
	
	/// The updater used to update this app.
	private var updater: SPUUpdater?
	
	// Callback to be called when the operation has been cancelled
	fileprivate var cancellationCallback: ((SPUDownloadUpdateStatus) -> Void)?
	
	/// Initializes the operation with the given Sparkle app and handler
	init(app: SparkleAppBundle, progressHandler: @escaping UpdateOperation.ProgressHandler, completionHandler: @escaping UpdateOperation.CompletionHandler) {
		super.init(app: app, progressHandler: progressHandler, completionHandler: completionHandler)
	}
	
	
	// MARK: - Operation Overrides
	
	override func execute() {
		super.execute()
		
		// Gather app and app bundle
		guard let app = self.app as? SparkleAppBundle, let bundle = Bundle(identifier: app.bundleIdentifier) else {
			self.finish(with: NSError.noUpdate)
			return
		}
		
		DispatchQueue.main.async {
			// Instantiate a new updater that performs the update
			let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: self, delegate: nil)
			
			do {
				try updater.start()
			} catch let error {
				self.finish(with: error)
			}
			
			updater.checkForUpdates()
			
			self.updater = updater
		}
	}
	
	override func cancel() {
		super.cancel()
		
		self.cancellationCallback?(.canceled)
		self.finish()
	}
	
	override func finish() {
		// Cleanup updater
		self.updater = nil
		
		super.finish()
	}
	
	
	// MARK: - Downloading
	
	/// The estimated total length of the downloaded app bundle.
	fileprivate var expectedContentLength: UInt64 = 0

	/// The length of already downloaded data.
	fileprivate var receivedLength: UInt64 = 0
	
	
	// MARK: - Installation
	
	/// Whether the app is open.
	fileprivate var isAppOpen = false
	
	/// One instance of the currently updating application.
	fileprivate var runningApplication: NSRunningApplication? {
		return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == self.app.bundleIdentifier })
	}

}


// MARK: - Driver Implementation
extension SparkleUpdateOperation: SPUUserDriver {
	
	// MARK: - Preparing Update
	
	func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
		reply(.init(automaticUpdateChecks: false, sendSystemProfile: false))
	}
	
	func showUserInitiatedUpdateCheck(completion updateCheckStatusCompletion: @escaping (SPUUserInitiatedCheckStatus) -> Void) {
		self.progressHandler(.initializing)
	}
	
	func showUpdateFound(with appcastItem: SUAppcastItem, userInitiated: Bool, reply: @escaping (SPUUpdateAlertChoice) -> Void) {
		reply(self.isCancelled ? .installLaterChoice : .installUpdateChoice)
	}
	
	func showDownloadedUpdateFound(with appcastItem: SUAppcastItem, userInitiated: Bool, reply: @escaping (SPUUpdateAlertChoice) -> Void) {
		reply(self.isCancelled ? .installLaterChoice : .installUpdateChoice)
	}
	
	func showResumableUpdateFound(with appcastItem: SUAppcastItem, userInitiated: Bool, reply: @escaping (SPUInstallUpdateStatus) -> Void) {
		reply(self.isCancelled ? .dismissUpdateInstallation : .installAndRelaunchUpdateNow)
	}
	
	func showInformationalUpdateFound(with appcastItem: SUAppcastItem, userInitiated: Bool, reply: @escaping (SPUInformationalUpdateAlertChoice) -> Void) {
		reply(.dismissInformationalNoticeChoice)
	}
	
	func showUpdateNotFound(acknowledgement: @escaping () -> Void) {
		self.finish(with: NSError.noUpdate)
		acknowledgement()
	}
	
	func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
		self.finish(with: error)
		acknowledgement()
	}
	
	func showDownloadInitiated(completion downloadUpdateStatusCompletion: @escaping (SPUDownloadUpdateStatus) -> Void) {
		if self.isCancelled {
			downloadUpdateStatusCompletion(.canceled)
			return
		}
		
		self.cancellationCallback = downloadUpdateStatusCompletion
	}

	
	// MARK: - Downloading Update
	
	func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
		// This should be only called once per download. If it Uis called more than once, reset the progress
		self.expectedContentLength = expectedContentLength
		self.receivedLength = 0
		
		self.callProgressHandler()
	}
	
	func showDownloadDidReceiveData(ofLength length: UInt64) {
		self.receivedLength += length

		// Expected content length may be wrong, adjust if needed
		self.expectedContentLength = max(self.expectedContentLength, self.receivedLength)
		
		self.callProgressHandler()
	}
	
	private func callProgressHandler() {
		self.progressHandler(.downloading(loadedSize: Int64(self.receivedLength), totalSize: Int64(self.expectedContentLength)))
	}

	
	// MARK: - Installing Update
	
	func showDownloadDidStartExtractingUpdate() {
		self.progressHandler(.extracting(progress: 0))
	}
	
	func showExtractionReceivedProgress(_ progress: Double) {
		self.progressHandler(.extracting(progress: progress))
	}
	
	func showReady(toInstallAndRelaunch installUpdateHandler: @escaping (SPUInstallUpdateStatus) -> Void) {
		// Check whether app is open
		self.isAppOpen = self.runningApplication != nil
		
		installUpdateHandler(self.isCancelled ? .dismissUpdateInstallation : .installAndRelaunchUpdateNow)
	}
	
	func showInstallingUpdate() {
		self.progressHandler(.installing)
	}
	
	func showUpdateInstallationDidFinish(acknowledgement: @escaping () -> Void) {
		// Close the app after installation when it was not open before
		if !self.isAppOpen, let runningApplication = self.runningApplication {
			// Attempt to terminate app gracefully
			runningApplication.terminate()
		}
		
		acknowledgement()
		self.finish()
	}
	

	// MARK: - Ignored Methods
	
	func showCanCheck(forUpdates canCheckForUpdates: Bool) {}
	func dismissUserInitiatedUpdateCheck() {}
	func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
	func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
	func showSendingTerminationSignal() {}
	func dismissUpdateInstallation() {}
	
}
