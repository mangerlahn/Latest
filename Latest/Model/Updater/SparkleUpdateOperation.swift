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
	private var updater: SUUpdater?
	
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
			let updater = SingleUseUpdater(for: bundle)
			updater?.delegate = self
			updater?.installUpdates(with: self.progressHandler)
			
			self.updater = updater
		}
	}
	
	override func cancel() {
		super.cancel()
		
		self.updater?.driver?.download.cancel()
		self.updater?.driver?.abortUpdate()
		
		self.finish()
	}
	
	
	// MARK: - Installation
	
	/// Whether the app is open.
	fileprivate var isAppOpen = false
	
	/// One instance of the currently updating application.
	fileprivate var runningApplication: NSRunningApplication? {
		return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == self.app.bundleIdentifier })
	}

}

// MARK: - Download Observer	
extension SparkleUpdateOperation: SUUpdaterDelegate {

	// MARK: Customization
	
	func updaterShouldPromptForPermissionToCheck(forUpdates updater: SUUpdater) -> Bool {
		// Don't show any Sparkle UI as we do that on our own
		return false
	}
	
	
	// MARK: Cancellation
	
	func updaterDidNotFindUpdate(_ updater: SUUpdater) {
		// No update was found, abort
		self.finish(with: NSError.noUpdate)
	}
	
	func userDidCancelDownload(_ updater: SUUpdater) {
		self.finish()
	}

	func updater(_ updater: SUUpdater, didAbortWithError error: Error) {
		self.finish(with: error)
	}
	
	func updater(_ updater: SUUpdater, didCancelInstallUpdateOnQuit item: SUAppcastItem) {
		self.finish()
	}
	
	
	// MARK: Installation
	
	func updaterShouldRelaunchApplication(_ updater: SUUpdater) -> Bool {
		return true
	}
	
	func updater(_ updater: SUUpdater, willInstallUpdate item: SUAppcastItem) {
		self.progressHandler(.installing)
	}
	
	func updaterWillRelaunchApplication(_ updater: SUUpdater) {
		// Check whether app is open
		self.isAppOpen = self.runningApplication != nil
	}
	
	func updaterDidRelaunchApplication(_ updater: SUUpdater) {
		// Close the app after installation when it was not open before
		if !self.isAppOpen, let runningApplication = self.runningApplication {
			// Attempt to terminate app gracefully
			runningApplication.terminate()
		}
		
		self.finish()
	}
	
}

/**
A subclass that overrides update scheduling to do nothing.
Each instance of `SUUpdater` is added to an internal static dictionary of updaters.
We are not able to expose this dictionary in order to remove the updater after this operation finishes.
Therefore one updater instance for each update check will be added to the dictionary.
While this is not ideal, we can still prevent any automatic update checks (with UI prompts) from occurring.
*/
class SingleUseUpdater: SUUpdater {
	
	override func startUpdateCycle() {
		// Prevent automatic update checking from taking place
	}
	
	override func scheduleNextUpdateCheck() {
		// Prevent automatic update checking from taking place
	}
	
	override func checkForUpdatesInBackground() {
		// This implementation should not check for updates
	}
	
	func installUpdates(with handler: @escaping UpdateOperation.ProgressHandler) {
		// Override the update driver to hide any form of UI
		let driver = UpdateDriver(updater: self, progressHandler: handler)
		
		// Automatically install the downloaded update
		driver.automaticallyInstallUpdates = true
		
		// Start the update process
		self.checkForUpdates(with: driver)
	}
	
}

/// A custom update driver that overrides the drivers delegate methods.
class UpdateDriver: SUBasicUpdateDriver {

	/// The handler with which progress is reported.
	let progressHandler: UpdateOperation.ProgressHandler
	
	/// Initializes the update driver with the given updater and progress handler.
	init(updater: SUUpdater, progressHandler: @escaping UpdateOperation.ProgressHandler) {
		self.progressHandler = progressHandler
		super.init(updater: updater)
	}
	
	
	// MARK: - Download Delegate Overrides
	
	/// The estimated total length of the downloaded app bundle.
	private var expectedContentLength: Int64 = 0
	
	/// The length of already downloaded data.
	private var receivedLength: Int64 = 0
	
	override func downloaderDidReceiveExpectedContentLength(_ expectedContentLength: Int64) {
		// This should be only called once per download. If it is called more than once, reset the progress
		self.expectedContentLength = expectedContentLength
		self.receivedLength = 0
		
		self.callProgressHandler()
	}
	
	override func downloaderDidReceiveData(ofLength length: UInt64) {
		self.receivedLength += Int64(length)
		
		// Expected content length may be wrong, adjust if needed
		self.expectedContentLength = max(self.expectedContentLength, self.receivedLength)
		
		self.callProgressHandler()
	}
	
	override func downloaderDidFinish(withTemporaryDownloadData downloadData: SPUDownloadData!) {
		self.progressHandler(.installing)
		super.downloaderDidFinish(withTemporaryDownloadData: downloadData)
	}
	
	
	// MARK: - Helper Methods
	
	private func callProgressHandler() {
		self.progressHandler(.downloading(loadedSize: self.receivedLength, totalSize: self.expectedContentLength))
	}
	
}
