//
//  VersionInfo.swift
//  Latest
//
//  Created by Max Langer on 01.11.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

extension App {
	
	/**
	 A simple class holding the update information for a single app.
	 */
	class Update: Equatable {
		
		/// The update for which this update exists.
		let app: App.Bundle
		
		/// The newest version of the app available for download.
		let remoteVersion: Version
		
		/// The minimum version required to perform this update.
		let minimumOSVersion: OperatingSystemVersion?
		
		/// The entity the update is being sourced from.
		let source: Source

		/// The release date of the update
		let date : Date?
		
		/// The release notes of the update
		let releaseNotes: ReleaseNotes?
		
		/// A handler performing the update action of the app.
		typealias UpdateAction = (_ app: App.Bundle) -> Void
		let updateAction: UpdateAction
		
		/// Initializes the update with the given parameters.
		init(app: App.Bundle, remoteVersion: Version, minimumOSVersion: OperatingSystemVersion?, source: Source, date: Date?, releaseNotes: ReleaseNotes?, updateAction: @escaping UpdateAction) {
			self.app = app
			self.remoteVersion = remoteVersion
			self.minimumOSVersion = minimumOSVersion
			self.source = source
			self.date = date
			self.releaseNotes = releaseNotes
			self.updateAction = updateAction
		}

		/// Whether an update is available for the given app.
		var updateAvailable: Bool {
			var updateAvailable = (remoteVersion > app.version)
			
			if updateAvailable, let minimumOSVersion {
				updateAvailable = ProcessInfo.processInfo.isOperatingSystemAtLeast(minimumOSVersion)
			}
			
			return updateAvailable
		}
		
		/// Whether the app is currently being updated.
		var isUpdating: Bool {
			return UpdateQueue.shared.contains(self.app.identifier)
		}

		
		// MARK: - Actions
				
		/// Updates the app. This is a sub-classing hook. The default implementation opens the app.
		final func perform() {
			guard !self.isUpdating else {
				fatalError("Attempt to perform update on app that is already updating.")
			}
			
			guard self.updateAvailable else {
				fatalError("Attempt to perform update on app that is already up to date.")
			}
			
			self.updateAction(self.app)
		}
		
		/// Cancels the scheduled update for this app.
		func cancelUpdate() {
			UpdateQueue.shared.cancelUpdate(for: self.app.identifier)
		}
		
		
		// MARK: - Equatable
		
		/// Compares the equality of UpdateInfo objects
		static func ==(lhs: Update, rhs: Update) -> Bool {
			return lhs.remoteVersion == rhs.remoteVersion && lhs.date == rhs.date
		}
		
	}
	
}

extension App.Update {
	
	/// Provides several types of release notes.
	enum ReleaseNotes {
		
		/// The url from which release notes can be fetched.
		case url(url: URL)
		
		/// The release notes in form of pre-formatted HTML.
		case html(string: String)
		
		/// Release notes encoded in the given data object.
		case encoded(data: Data)
		
	}
	
}

extension App.Update: CustomDebugStringConvertible {
	var debugDescription: String {
		return self.remoteVersion.debugDescription
	}
}
