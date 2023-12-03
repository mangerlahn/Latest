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
		let updateAction: Action
		
		/// Initializes the update with the given parameters.
		init(app: App.Bundle, remoteVersion: Version, minimumOSVersion: OperatingSystemVersion?, source: Source, date: Date?, releaseNotes: ReleaseNotes?, updateAction: Action) {
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
			var updateAvailable = app.version < remoteVersion
			
			if updateAvailable, let minimumOSVersion {
				updateAvailable = ProcessInfo.processInfo.isOperatingSystemAtLeast(minimumOSVersion)
			}
			
			return updateAvailable
		}
		
		/// Whether the app is currently being updated.
		var isUpdating: Bool {
			return UpdateQueue.shared.contains(self.app.identifier)
		}
		
		/// Whether the update is performed using a built in updater.
		var usesBuiltInUpdater: Bool {
			externalUpdaterName == nil
		}
		
		/// The name of the external updater used to update this app.
		var externalUpdaterName: String? {
			if case .external(let label, _) = updateAction { label } else { nil }
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
			
			self.updateAction.perform(with: self.app)
		}
		
		/// Cancels the scheduled update for this app.
		func cancelUpdate() {
			UpdateQueue.shared.cancelUpdate(for: self.app.identifier)
		}
		
		
		// MARK: - Sanitization
		
		/// Returns a sanitized update for the given app bundle.
		func sanitized(for bundle: App.Bundle) -> Update {
			let version = remoteVersion.sanitize(with: bundle.version)
			guard version != remoteVersion else { return self }
			
			// Modify just the remote version
			return Update(app: app, remoteVersion: version, minimumOSVersion: minimumOSVersion, source: source, date: date, releaseNotes: releaseNotes, updateAction: updateAction)
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

extension App.Update {
	
	typealias UpdateAction = (_ app: App.Bundle) -> Void
	
	/// Defines possible update actions.
	enum Action {
		
		/// The update will be performed within this app.
		case builtIn(block: UpdateAction)
		
		/// No updater is available to update this app. An external program will be launched to perform the update.
		case external(label: String, block: UpdateAction)
		
		/// Performs the update for the given bundle.
		func perform(with bundle: App.Bundle) {
			switch self {
			case .builtIn(let block):
				block(bundle)
			case .external(_, let block):
				block(bundle)
			}
		}
	}
	
}
