//
//  LatestError.swift
//  Latest
//
//  Created by Max Langer on 08.01.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

/// Provides errors within the app's error domain.
enum LatestError: Int, CustomNSError {
	
	/// The update info for a given app could not be loaded.
	case updateInfoNotFound
	
	/// An error to be used when no release notes were found for a given app.
	case releaseNotesUnavailable
	
	
	// MARK: - NSError Protocol
	
	/// The domain of the app's errors.
	static var errorDomain: String {
		"com.max-langer.latest"
	}
	
	/// The code of the error.
	var errorCode: Int {
		return self.rawValue
	}
	
	/// The localized description of the error.
	var localizedDescription: String {
		switch self {
			case .updateInfoNotFound:
				return NSLocalizedString("UpdateInfoNotFoundError", comment: "Error message stating that update info could not be retrieved for a given app.")
				
			case .releaseNotesUnavailable:
				return NSLocalizedString("NoReleaseNotesFoundError", comment: "Error message that no release notes were found")
		}
	}
	
}
