//
//  SparkleUpdateOperation.swift
//  Latest
//
//  Created by Max Langer on 01.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import AppKit
import Sparkle

/// The operation updating Sparkle apps.
class SparkleUpdateOperation: UpdateOperation, @unchecked Sendable {
	
	/// The updater used to update this app.
	private var updater: SPUUpdater?
	
	// Callback to be called when the operation has been cancelled
	fileprivate var cancellationCallback: (() -> Void)?

	/// The location of the app bundle to update.
	///
	/// `App.Bundle.Identifier` is the bundle's file URL, so the identifier the operation was
	/// created with doubles as the on-disk location of the app being updated.
	private let fileURL: URL

	/// Initializes the operation with the given Sparkle app and handler
	override init(bundleIdentifier: String, appIdentifier: App.Bundle.Identifier) {
		self.fileURL = appIdentifier
		super.init(bundleIdentifier: bundleIdentifier, appIdentifier: appIdentifier)
	}


	// MARK: - Operation Overrides
	
	override func execute() {
		super.execute()

		// Gather app and app bundle. `Bundle(identifier:)` only ever resolves bundles that are
		// already loaded into this process, so it cannot find the app being updated. Load it
		// from its known location instead, keeping the identifier lookup as a last-resort
		// fallback.
		guard let bundle = Bundle(url: self.fileURL) ?? Bundle(path: self.fileURL.path) ?? Bundle(identifier: self.bundleIdentifier) else {
			self.finish(with: LatestError.updateInfoUnavailable)
			return
		}
		
		DispatchQueue.main.async {
			// A cancellation can win the race against this hop. Its teardown has already
			// completed, so building an updater here would resurrect an operation nothing
			// will tear down again, leaving Sparkle running against a dead operation.
			guard !self.isTornDown else { return }

			// Instantiate a new updater that performs the update
			let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: self, delegate: self)

			// Publish ownership before starting. `start()` can synchronously drive
			// user-driver callbacks that finish the operation and reenter teardown; that
			// teardown must be able to find and release this instance rather than leave it
			// running unowned.
			self.updater = updater

			do {
				try updater.start()
			} catch let error {
				self.finish(with: error)
				return
			}

			// Re-check: teardown may have run reentrantly from `start()`. Checking for
			// updates now would start work on an operation that has already torn down.
			// `updater` is deliberately not reassigned here — teardown may have cleared it
			// on purpose.
			guard !self.isTornDown else { return }

			updater.checkForUpdates()
		}
	}
	
	override func cancel() {
		// cancel() can be invoked from any thread, but SPUUpdater and Sparkle's cancellation
		// closure are main-thread-only. Do not touch either here: just flip the cancelled
		// flag and finish. `finish()` owns the teardown and sees `isCancelled == true`, so
		// it invokes and consumes the cancellation closure on the main thread, exactly once.
		super.cancel()
		self.finish()
	}
	
	override func finish() {
		// Single owner of teardown for every finish path: user cancellation, success, error,
		// and cancelled-before-start. On a user cancellation, invoke and consume Sparkle's
		// cancellation closure; a normal success or error finish must not invoke it. Running
		// before `super.finish()` guarantees teardown completes — and pending download
		// progress is retired — before the terminal progress state is published.
		self.performTeardownOnMain(invokeCancellation: self.isCancelled)

		super.finish()
	}

	/// Whether teardown has begun. Main-confined.
	///
	/// `isFinished` cannot answer this: the teardown in `finish()` runs *before*
	/// `StatefulOperation` transitions the operation to its finished state, so there is a
	/// window in which teardown has completed while both `isFinished` and `isCancelled`
	/// still read false. Sparkle callbacks and the queued initialization block land on the
	/// main thread inside that window.
	private var teardownStarted = false

	/// Whether the operation has stopped accepting new Sparkle work. Main-confined.
	private var isTornDown: Bool {
		assert(Thread.isMainThread, "Must be called on main thread.")
		return self.teardownStarted || self.isCancelled || self.isFinished
	}

	/// Releases the updater and, when `invokeCancellation` is true, invokes Sparkle's
	/// cancellation closure — both synchronously on the main thread, because `SPUUpdater`
	/// and the closure are main-thread-only. Synchronous execution is deadlock-free here:
	/// nothing this operation schedules on the main queue ever blocks on the thread calling
	/// `finish()` (observer notification in `UpdateQueue` is `DispatchQueue.main.async`).
	/// The closure is read-and-cleared so it is invoked at most once across every finish
	/// path, and a stored closure can no longer leak on a success or error finish.
	private func performTeardownOnMain(invokeCancellation: Bool) {
		let work = {
			// Set first, before anything below can reenter: this is the only flag that
			// reports "teardown already ran" inside the pre-`isFinished` window.
			self.teardownStarted = true

			// Retire pending and scheduled download progress before the terminal state is
			// published, so no trailing `.downloading` can land after `.none`/`.error`.
			self.invalidateProgressPublishing()

			// Always consume the closure, even when it must not be invoked: leaving it
			// stored on a success or error finish strands Sparkle's download cancellation.
			// Reading and clearing before the call also keeps it at most once under
			// reentrancy.
			let callback = self.cancellationCallback
			self.cancellationCallback = nil
			if invokeCancellation {
				callback?()
			}

			self.updater = nil
		}

		if Thread.isMainThread {
			work()
		} else {
			DispatchQueue.main.sync(execute: work)
		}
	}


	// MARK: - Downloading
	
	/// The estimated total length of the downloaded app bundle.
	fileprivate var expectedContentLength: UInt64 = 0

	/// The length of already downloaded data.
	fileprivate var receivedLength: UInt64 = 0

	/// The minimum interval between two progress publications.
	private static let progressPublicationInterval: DispatchTimeInterval = .seconds(1)

	/// The most recent byte counts reported by Sparkle, awaiting publication.
	private var pendingProgress: (loadedSize: Int64, totalSize: Int64)?

	/// When the last progress state was published, if any.
	private var lastProgressPublication: DispatchTime?

	/// Whether a trailing publication has already been scheduled.
	///
	/// While true, further activity only refreshes `pendingProgress`; the scheduled work
	/// publishes whatever the latest counts are when it runs.
	private var hasScheduledProgressPublication = false

	/// The publishing epoch a scheduled trailing publication belongs to.
	///
	/// A delayed block captures this value and drops out if it no longer matches, which is
	/// what makes an already-queued block inert once a later phase has taken over the
	/// progress state.
	private var progressGeneration: UInt64 = 0

	/// Whether download progress may still be published.
	///
	/// Cleared for good once extraction starts or teardown runs, so a stray late download
	/// callback cannot reactivate publishing and overwrite a later phase.
	private var isProgressPublishingActive = true


	// MARK: - Installation
	
	/// Whether the app is open.
	fileprivate var isAppOpen = false
	
	/// One instance of the currently updating application.
	fileprivate var runningApplication: NSRunningApplication? {
		return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == self.bundleIdentifier })
	}

}

// MARK: - Driver Implementation
extension SparkleUpdateOperation: SPUUserDriver {
	
	// MARK: - Preparing Update
	
	func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
		reply(.init(automaticUpdateChecks: false, sendSystemProfile: false))
	}
	
	func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
		self.progressState = .initializing
	}
	
	func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
		reply(self.isCancelled ? .dismiss : .install)
	}
		
	func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
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
	
	func showUpdateInFocus() {
		// Noop
	}

	func showDownloadInitiated(cancellation: @escaping () -> Void) {
		// Sparkle invokes user-driver callbacks on the main thread, so this and the closure
		// it hands us are main-thread-safe. If teardown already ran — which `isTornDown`
		// reports even inside the window where teardown completed but `isFinished` is still
		// false — invoke the closure immediately and do not store it: nothing will consume a
		// closure stored after teardown, so storing it would leave the download running
		// forever. This direct call is then the single, at-most-once invocation. Otherwise
		// store it for the finish path.
		if self.isTornDown {
			cancellation()
			return
		}

		self.cancellationCallback = cancellation
	}
	
	// MARK: - Downloading Update
	
	func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
		// This should be only called once per download. If it Uis called more than once, reset the progress
		self.expectedContentLength = expectedContentLength
		self.receivedLength = 0
		
		self.scheduleProgressHandler()
	}
	
	func showDownloadDidReceiveData(ofLength length: UInt64) {
		self.receivedLength += length

		// Expected content length may be wrong, adjust if needed
		self.expectedContentLength = max(self.expectedContentLength, self.receivedLength)
		
		self.scheduleProgressHandler()
	}

	/// Coalesces download activity into at most one progress publication per second.
	///
	/// The whole coalescer is main-confined: Sparkle delivers user-driver callbacks on the
	/// main thread and teardown synchronizes onto it, so phase changes and lifecycle
	/// transitions are ordered against the coalescing state by the main queue alone — no
	/// extra queue or lock, and no thread is ever blocked to pace publications.
	///
	/// Publishes immediately when the last publication is at least
	/// `progressPublicationInterval` old, otherwise defers to the end of the current
	/// interval. Activity arriving while a publication is already deferred only refreshes
	/// the pending byte counts, so the deferred work always publishes the latest values —
	/// and, because the last burst of a download still schedules one, a trailing update
	/// always follows activity. No timer exists while the download is idle.
	private func scheduleProgressHandler() {
		assert(Thread.isMainThread, "Must be called on main thread.")
		guard self.isProgressPublishingActive else { return }

		self.pendingProgress = (loadedSize: Int64(self.receivedLength), totalSize: Int64(self.expectedContentLength))

		// A deferred publication is already pending and will pick up the counts just stored.
		guard !self.hasScheduledProgressPublication else { return }

		guard let last = self.lastProgressPublication,
			  last + Self.progressPublicationInterval > .now() else {
			self.publishPendingProgress()
			return
		}

		let generation = self.progressGeneration
		self.hasScheduledProgressPublication = true

		DispatchQueue.main.asyncAfter(deadline: last + Self.progressPublicationInterval) { [weak self] in
			guard let self = self else { return }

			// Invalidated while this block was queued: a later phase owns the progress
			// state now, and it already reset the scheduling flag. Do nothing at all.
			guard self.progressGeneration == generation else { return }

			self.hasScheduledProgressPublication = false
			self.publishPendingProgress()
		}
	}

	/// Publishes the pending byte counts as the operation's progress state.
	private func publishPendingProgress() {
		assert(Thread.isMainThread, "Must be called on main thread.")
		guard self.isProgressPublishingActive, let progress = self.pendingProgress else { return }

		self.pendingProgress = nil
		self.lastProgressPublication = .now()
		self.progressState = .downloading(loadedSize: progress.loadedSize, totalSize: progress.totalSize)
	}

	/// Retires download progress publication, handing the progress state to a later phase.
	///
	/// Bumping the generation makes an already-scheduled trailing block inert, and clearing
	/// the active flag stops a late download callback from starting a fresh one. Called
	/// synchronously on the main thread before extraction publishes `.extracting` and inside
	/// teardown before the terminal state is published, so once either has run no
	/// `.downloading` can be published — or, because observers are notified via
	/// `main.async`, be *delivered* — after the state that superseded it.
	private func invalidateProgressPublishing() {
		assert(Thread.isMainThread, "Must be called on main thread.")
		self.progressGeneration &+= 1
		self.pendingProgress = nil
		self.hasScheduledProgressPublication = false
		self.isProgressPublishingActive = false
	}


	// MARK: - Installing Update
	
	func showDownloadDidStartExtractingUpdate() {
		// Downloading is over. Retire any trailing download publication first, otherwise it
		// lands after this and leaves the UI showing download progress during extraction.
		self.invalidateProgressPublishing()
		self.progressState = .extracting(progress: 0)
	}
	
	func showExtractionReceivedProgress(_ progress: Double) {
		self.progressState = .extracting(progress: progress)
	}
	
	func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
		// Check whether app is open
		self.isAppOpen = self.runningApplication != nil
		
		reply(self.isCancelled ? .dismiss : .install)
	}
	
	func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
		self.progressState = .installing
	}
		

	// MARK: - Ignored Methods
	
	func showCanCheck(forUpdates canCheckForUpdates: Bool) {}
	func dismissUserInitiatedUpdateCheck() {}
	func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
	func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
	func showSendingTerminationSignal() {}
	func dismissUpdateInstallation() {}
	
}

extension SparkleUpdateOperation: SPUUpdaterDelegate {
	
	func feedURLString(for updater: SPUUpdater) -> String? {
		// We can try to supply a valid feed as addition to Sparkle's own methods.
		// For some cases (like DevMate) Sparkle fails to retrieve an appcast by itself.
		return Sparke.feedURL(from: updater.hostBundle)?.absoluteString
	}
	
}
