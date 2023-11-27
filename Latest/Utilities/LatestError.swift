//
//  LatestError.swift
//  Latest
//
//  Created by Max Langer on 08.01.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

/// Provides errors within the app's error domain.
enum LatestError: LocalizedError {
	
	/// The update info for a given app could not be loaded.
	case updateInfoUnavailable
	
	/// An error to be used when no release notes were found for a given app.
	case releaseNotesUnavailable
	
	/// An error raised by the App Store updater in case the user is not signed in.
	case notSignedInToAppStore
	
	case custom(title: String, description: String?)
	
	
	// MARK: - Localized Error Protocol
	
	/// The localized description of the error.
	var localizedDescription: String {
		switch self {
			case .updateInfoUnavailable:
				return NSLocalizedString("UpdateInfoUnavailableError", comment: "Short description of error stating that update info could not be retrieved for a given app.")
				
			case .releaseNotesUnavailable:
				return NSLocalizedString("ReleaseNotesUnavailableError", comment: "Short description of error that no release notes were found.")
				
			case .notSignedInToAppStore:
				return NSLocalizedString("AppStoreNotSignedInError", comment: "Short description of error when no update was found for a particular app.")
			
			case .custom(let title, _):
				return title
		}
	}
	
	var errorDescription: String? {
		localizedDescription
	}
	
	var failureReason: String? {
		switch self {
		case .updateInfoUnavailable:
			return NSLocalizedString("UpdateInfoUnavailableErrorFailureReason", comment: "Error message stating that update info could not be retrieved for a given app.")
			
		case .releaseNotesUnavailable:
			return NSLocalizedString("ReleaseNotesUnavailableErrorFailureReason", comment: "Error message that no release notes were found.")
			
		case .notSignedInToAppStore:
			return nil
			
		case .custom(_ , let description):
			return description
		}
	}
	
	var recoverySuggestion: String? {
		switch self {
		case .updateInfoUnavailable:
			return nil
			
		case .releaseNotesUnavailable:
			return nil
			
		case .notSignedInToAppStore:
			return NSLocalizedString("AppStoreNotSignedInErrorRecoverySuggestion", comment: "Error description when the attempt to update an app from the App Store failed because the user is not signed in with their App Store account.")
			
		case .custom(_ , _):
			return nil
		}

	}
	
}
