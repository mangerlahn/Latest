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
		// Use a dispatch group for the initial setup to get contents for all directories before gathering apps
		var dispatchGroup: DispatchGroup? = self.directories.isEmpty ? DispatchGroup() : nil
		
		// Setup directories
		directories = Dictionary(uniqueKeysWithValues: directoryStore.URLs.compactMap { url in
			// Skip unreachable directories
			guard directoryStore.isReachable(url) else { return nil }
			
			dispatchGroup?.enter()
			
			// Reuse existing directory observations if possible
			return (url, directories[url] ?? AppDirectory(url: url) {
				if let dispatchGroup {
					// Initial mode, notify dispatch group
					dispatchGroup.leave()
				} else {
					// Schedule update
					self.updateScheduler.add(data: 1)
				}
			})
		})
		
		dispatchGroup?.notify(queue: .global()) {
			// Call update immediately. Using the scheduler delays the update.
			self.performUpdate()
			dispatchGroup = nil
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
