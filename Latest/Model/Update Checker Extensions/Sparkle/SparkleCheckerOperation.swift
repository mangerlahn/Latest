//
//  MacAppStoreUpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa
import Sparkle

/// The operation for checking for updates for a Sparkle app.
class SparkleUpdateCheckerOperation: StatefulOperation, UpdateCheckerOperation, @unchecked Sendable {
	
	// MARK: - Update Check
	
	static func canPerformUpdateCheck(forAppAt url: URL) -> Bool {
		// Can check for updates if a feed URL is available for the given app
		return Self.feedURL(from: url) != nil
	}

	static var sourceType: App.Source {
		return .sparkle
	}
	
	required init(with app: App.Bundle, repository: UpdateRepository?, completionBlock: @escaping UpdateCheckerCompletionBlock) {
		self.app = app
		self.url = Self.feedURL(from: app.fileURL)
		
		super.init()

		self.completionBlock = {
			guard !self.isCancelled else { return }
			if let update = self.update {
				completionBlock(.success(update))
			} else {
				completionBlock(.failure(self.error ?? LatestError.updateInfoUnavailable))
			}
		}
	}
	
	/// Returns the Sparkle feed url for the app at the given URL, if available.
	private static func feedURL(from appURL: URL) -> URL? {
		guard let bundle = Bundle(path: appURL.path) else { return nil }
		return Sparke.feedURL(from: bundle)
	}

	/// The bundle to be checked for updates.
	private let app: App.Bundle
	
	/// The url to check for updates.
	private let url: URL?
	
	/// The update fetched during the checking operation.
	fileprivate var update: App.Update?

	/// The updater used to check for updates to this app.
	private var updater: SPUUpdater?

	
	// MARK: - Operation
	
	override func execute() {
		// Gather app and app bundle
		guard let bundle = Bundle(identifier: self.app.bundleIdentifier) else {
			self.finish(with: LatestError.updateInfoUnavailable)
			return
		}
		
		DispatchQueue.main.async {
			// Instantiate a new updater that performs the update
			let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: self, delegate: self)
			
			do {
				try updater.start()
			} catch let error {
				self.finish(with: error)
			}
			
			updater.checkForUpdates()
			
			self.updater = updater
		}
	}
	
	fileprivate func finish(with appcastItem: SUAppcastItem) {
		let version = Version(versionNumber: appcastItem.displayVersionString, buildNumber: appcastItem.versionString)
		
		// OS Version
		var minimumOSVersion: OperatingSystemVersion? = nil
		if let minimumVersion = appcastItem.minimumSystemVersion {
			minimumOSVersion = try? OperatingSystemVersion(string: minimumVersion)
		}
		
		// Release Notes
		var releaseNotes: App.Update.ReleaseNotes? = nil
		if let description = appcastItem.itemDescription {
			releaseNotes = .html(string: description)
		} else if let url = appcastItem.releaseNotesURL ?? appcastItem.fullReleaseNotesURL {
			releaseNotes = .url(url: url)
		}
		
		// Build update
		self.update = App.Update(app: self.app, remoteVersion: version, minimumOSVersion: minimumOSVersion, source: .sparkle, date: appcastItem.date, releaseNotes: releaseNotes, updateAction: .builtIn(block: { app in
			UpdateQueue.shared.addOperation(SparkleUpdateOperation(bundleIdentifier: app.bundleIdentifier, appIdentifier: app.identifier))
		}))

		DispatchQueue.main.async(execute: {
			self.finish()
		})
	}
}

// MARK: - Driver Implementation
extension SparkleUpdateCheckerOperation: SPUUserDriver {
	
	// MARK: - Checking for Updates
	
	func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
		reply(.init(automaticUpdateChecks: false, sendSystemProfile: false))
	}
	
	func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
		self.finish(with: appcastItem)
	}
		
	func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
		let nsError = error as NSError
		if nsError.domain == SUSparkleErrorDomain && nsError.code == SUError.noUpdateError.rawValue, let appcastItem = nsError.userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem {
			self.finish(with: appcastItem)
		}
		
		self.finish(with: error)
		acknowledgement()
	}
	
	func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
		self.finish(with: error)
		acknowledgement()
	}
	
	func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
		acknowledgement()
		self.finish()
	}

	
	// MARK: - Ignored Methods
	func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
	func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
	func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

	func showUpdateInFocus() {}
	func showDownloadInitiated(cancellation: @escaping () -> Void) {}
	func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
	func showDownloadDidReceiveData(ofLength length: UInt64) {}
	private func scheduleProgressHandler() {}
	
	func showDownloadDidStartExtractingUpdate() {}
	func showExtractionReceivedProgress(_ progress: Double) {}
	func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {}
	func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}

	func showCanCheck(forUpdates canCheckForUpdates: Bool) {}
	func dismissUserInitiatedUpdateCheck() {}
	func showSendingTerminationSignal() {}
	func dismissUpdateInstallation() {}
	
}

extension SparkleUpdateCheckerOperation: SPUUpdaterDelegate {
	
	func feedURLString(for updater: SPUUpdater) -> String? {
		// We can try to supply a valid feed as addition to Sparkle's own methods.
		// For some cases (like DevMate) Sparkle fails to retrieve an appcast by itself.
		return url?.absoluteString
	}
	
}
