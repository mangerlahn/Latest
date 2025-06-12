//
//  DirectoryObserver.swift
//  Latest
//
//  Created by Max Langer on 02.01.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

/// The folder listener listens for changes in the given directory and then runs the update checker on changes
class AppDirectory {
	
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
	private var collectionQueue = DispatchQueue(label: "DataStoreQueue")

	
	/// The file system listener
	private lazy var listener : DispatchSourceFileSystemObject = {
		let descriptor = open((self.url as NSURL).fileSystemRepresentation, O_EVTONLY)
		guard descriptor != -1 else { fatalError("Unable to open folder at url") }
		
		let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
															   eventMask: .write)
		
		source.setEventHandler(handler: collectBundles)
		
		return source
	}()
	
	/// Initializes the class and resumes the listener automatically
	init(url: URL, updateHandler: @escaping UpdateHandler) {
		self.url = url
		self.handler = updateHandler
		
		resumeTracking()
	}
	
	deinit {
		listener.cancel()
	}
	
	/// Resumes tracking if it is not already running
	private func resumeTracking() {
		listener.activate()
		collectBundles()
	}
	
	/// Triggers an update run
	private func collectBundles() {
		bundles = BundleCollector.collectBundles(at: self.url)
	}
	
}
