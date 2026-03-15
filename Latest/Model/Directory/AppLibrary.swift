//
//  AppLibrary.swift
//  Latest
//
//  Created by Max Langer on 08.01.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

import Foundation

/// Observes the local collection of apps and notifies its owner of changes.
class AppLibrary {
	
	/// The handler to be called when apps change locally.
	typealias UpdateHandler = ([App.Bundle]) -> Void
	let updateHandler: UpdateHandler
	
	/// A list of all application bundles that are available locally.
	var bundles: [App.Bundle] {
		directories.flatMap { $0.value.bundles}
	}
		
	private var directories = [URL: AppDirectory]()
	
	/// Initializes the library with the given handler for updates.
	init(handler: @escaping UpdateHandler) {
		self.updateHandler = handler
	}
	
	private lazy var updateScheduler: DispatchSourceUserDataAdd = {
		let scheduler = DispatchSource.makeUserDataAddSource(queue: .global())
		
		scheduler.setEventHandler() { [weak self] in
			guard let self else { return }
			
			// Multiple content changes can, coalesc futher updates
			Thread.sleep(forTimeInterval: 10)
			
			self.performUpdate()
		}
		
		scheduler.activate()
		return scheduler
	}()

	
	// MARK: - Actions
	
	/// Starts the update checking process
	func startQuery() {
		DispatchQueue.global().async {
			self.setupDirectoryObservers()
		}
	}
		
	private func setupDirectoryObservers() {
		// Use a dispatch group for the initial setup to get contents for all directories before gathering apps.
		// Each directory may emit multiple updates while it is being initialized, so only the first callback
		// should fulfill the startup group.
		let dispatchGroup = self.directories.isEmpty ? DispatchGroup() : nil
		let existingDirectories = self.directories
		
		// Setup directories
		directories = Dictionary(uniqueKeysWithValues: directoryStore.URLs.compactMap { url in
			// Skip unreachable directories
			guard directoryStore.isReachable(url) else { return nil }
			
			// Reuse existing directory observations if possible
			if let existingDirectory = existingDirectories[url] {
				return (url, existingDirectory)
			}
			
			dispatchGroup?.enter()
			
			let initialLoadLock = NSLock()
			var initialLoadCompleted = false
			
			return (url, AppDirectory(url: url) {
				initialLoadLock.lock()
				let isInitialLoad = !initialLoadCompleted
				if isInitialLoad {
					initialLoadCompleted = true
				}
				initialLoadLock.unlock()
				
				if isInitialLoad {
					dispatchGroup?.leave()
				} else {
					self.updateScheduler.add(data: 1)
				}
			})
		})
		
		dispatchGroup?.notify(queue: .global()) {
			// Call update immediately. Using the scheduler delays the update.
			self.performUpdate()
		}
	}
	
	private func performUpdate() {
		updateHandler(bundles)
	}

	
	
	// MARK: - Directory Handling
	
	/// The store handling application directories.
	private lazy var directoryStore = {
		AppDirectoryStore(updateHandler: self.startQuery)
	}()
	
}
