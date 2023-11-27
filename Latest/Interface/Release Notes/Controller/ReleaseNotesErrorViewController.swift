//
//  ReleaseNotesErrorViewController.swift
//  Latest
//
//  Created by Max Langer on 12.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

/// The controller presenting errors to the user
class ReleaseNotesErrorViewController: NSViewController {

    /// The textField holding the error title
    @IBOutlet private weak var titleTextField: NSTextField!
    
    /// The textField holding the error description
    @IBOutlet private weak var descriptionTextField: NSTextField!
 
    /// Updates the description of the error
    func show(_ error: Error) {
		if let localizedError = error as? LocalizedError, let failureReason = localizedError.failureReason {
			titleTextField.stringValue = localizedError.localizedDescription
			descriptionTextField.stringValue = failureReason
		} else {
			descriptionTextField.stringValue = error.localizedDescription
		}
    }
    
}

extension ReleaseNotesErrorViewController: ReleaseNotesContentProtocol {
    
    typealias ReleaseNotesContentController = ReleaseNotesErrorViewController
    
    static var StoryboardIdentifier: String {
        return "ReleaseNotesErrorViewControllerIdentifier"
    }
    
}
