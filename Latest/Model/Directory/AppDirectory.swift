//
//  DirectoryObserver.swift
//  Latest
//
//  Created by Max Langer on 02.01.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa
import CoreServices

/// The folder listener listens for changes in the given directory and then runs the update checker on changes
class AppDirectory {

	typealias DescriptorProvider = (URL) -> (descriptor: CInt, error: Error?)
	typealias ObservationErrorHandler = (URL, Error) -> Void
	
	/// The url on which the listener reacts to changes on
	let url : URL
	
	/// The bundles collected within this directory.
	var bundles = [App.Bundle]() {
		didSet {
			handler()
		}
	}
	
	typealias UpdateHandler = () -> Void
	
	/// The handler to be called once the directory contents change.
	let handler: UpdateHandler
	
	/// The queue on which updates to the collection are being performed.
	private lazy var collectionQueue = DispatchQueue(label: "AppDirectory.collection.\(url.path)", qos: .utility)

	private let descriptorProvider: DescriptorProvider
	private let observationErrorHandler: ObservationErrorHandler?

	
	/// Recursive file system listener for the tracked directory.
	private lazy var listener = RecursiveDirectoryMonitor(url: self.url, queue: collectionQueue) { [weak self] in
		self?.collectBundles()
	}
	
	/// Initializes the class and resumes the listener automatically
	init(
		url: URL,
		updateHandler: @escaping UpdateHandler,
		descriptorProvider: @escaping DescriptorProvider = AppDirectory.openDescriptor,
		observationErrorHandler: ObservationErrorHandler? = nil
	) {
		self.url = url
		self.handler = updateHandler
		self.descriptorProvider = descriptorProvider
		self.observationErrorHandler = observationErrorHandler
		
		resumeTracking()
	}
	
	deinit {
		listener.stop()
	}
	
	/// Resumes tracking if it is not already running
	private func resumeTracking() {
		guard canObserveDirectory() else {
			DiagnosticsLog.trace(.appDirectory, "canObserveDirectory failed path=\(url.path)")
			collectBundles()
			return
		}
		
		if let error = listener.start() {
			DiagnosticsLog.trace(.appDirectory, "listener.start failed path=\(url.path) error=\(error.localizedDescription)")
			observationErrorHandler?(url, error)
		}
		collectBundles()
	}
	
	/// Triggers an update run
	private func collectBundles() {
		collectionQueue.async {
			DiagnosticsLog.trace(.appDirectory, "collectBundles start path=\(self.url.path)")
			let bundles = BundleCollector.collectBundles(at: self.url) { failedURL, error in
				DiagnosticsLog.trace(.appDirectory, "collectBundles error path=\(failedURL.path) error=\(error.localizedDescription)")
				self.observationErrorHandler?(failedURL, error)
			}
			DiagnosticsLog.trace(.appDirectory, "collectBundles finished path=\(self.url.path) bundles=\(bundles.count)")
			self.bundles = bundles
		}
	}

	private func canObserveDirectory() -> Bool {
		let result = descriptorProvider(url)
		guard result.descriptor != -1 else {
			if let error = result.error {
				DiagnosticsLog.trace(.appDirectory, "openDescriptor failed path=\(url.path) error=\(error.localizedDescription)")
				observationErrorHandler?(url, error)
			}
			return false
		}
		
		close(result.descriptor)
		return true
	}

	private static func openDescriptor(for url: URL) -> (descriptor: CInt, error: Error?) {
		let descriptor = open((url as NSURL).fileSystemRepresentation, O_EVTONLY)
		guard descriptor == -1 else {
			return (descriptor, nil)
		}
		
		let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
			NSFilePathErrorKey: url.path
		])
		return (-1, error)
	}
	
}

/// Recursive directory monitor backed by FSEvents.
private final class RecursiveDirectoryMonitor {
	
	typealias EventHandler = () -> Void
	
	private let url: URL
	private let queue: DispatchQueue
	private let eventHandler: EventHandler
	private var stream: FSEventStreamRef?
	private var isStarted = false
	
	init(url: URL, queue: DispatchQueue, eventHandler: @escaping EventHandler) {
		self.url = url
		self.queue = queue
		self.eventHandler = eventHandler
	}
	
	deinit {
		stop()
	}
	
	func start() -> Error? {
		guard !isStarted else { return nil }
		guard let stream = makeStream() else {
			return Self.makeStartError(for: url)
		}
		
		self.stream = stream
		FSEventStreamSetDispatchQueue(stream, queue)
		guard FSEventStreamStart(stream) else {
			stop()
			return Self.makeStartError(for: url)
		}
		
		isStarted = true
		return nil
	}
	
	func stop() {
		guard let stream else { return }
		
		FSEventStreamStop(stream)
		FSEventStreamInvalidate(stream)
		FSEventStreamRelease(stream)
		self.stream = nil
		isStarted = false
	}
	
	private func makeStream() -> FSEventStreamRef? {
		var context = FSEventStreamContext(
			version: 0,
			info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
			retain: nil,
			release: nil,
			copyDescription: nil
		)
		
		let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
		
		return FSEventStreamCreate(
			nil,
			{ _, info, _, _, _, _ in
				guard let info else { return }
				let monitor = Unmanaged<RecursiveDirectoryMonitor>.fromOpaque(info).takeUnretainedValue()
				monitor.eventHandler()
			},
			&context,
			[url.path] as CFArray,
			FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
			0.5,
			flags
		)
	}
	
	private static func makeStartError(for url: URL) -> Error {
		NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: [
			NSLocalizedDescriptionKey: NSLocalizedString("DirectoryObservationUnavailableError", comment: "Error shown when Latest cannot start recursive monitoring for a configured app scan directory."),
			NSFilePathErrorKey: url.path
		])
	}
	
}
