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
	
	/// The url on which the listener reacts to changes on
	let url: URL
	
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
	private let collectionQueue = DispatchQueue(label: "DataStoreQueue")
	
	/// Recursive file system listener for the tracked directory.
	private lazy var listener = RecursiveDirectoryMonitor(url: self.url, queue: collectionQueue) { [weak self] in
		self?.collectBundles()
	}
	
	/// Initializes the class and resumes the listener automatically
	init(url: URL, updateHandler: @escaping UpdateHandler) {
		self.url = url
		self.handler = updateHandler
		
		resumeTracking()
	}
	
	/// Resumes tracking if it is not already running
	private func resumeTracking() {
		listener.start()
		collectBundles()
	}
	
	/// Triggers an update run
	private func collectBundles() {
		bundles = BundleCollector.collectBundles(at: self.url)
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
	
	func start() {
		guard !isStarted, let stream = makeStream() else { return }
		
		self.stream = stream
		FSEventStreamSetDispatchQueue(stream, queue)
		FSEventStreamStart(stream)
		isStarted = true
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
	
}
