//
//  ReleaseNotesLoadingViewController.swift
//  Latest
//
//  Created by Max Langer on 12.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

/// The controller presenting a small activity indicator, showing the user that release notes are currently loading
class ReleaseNotesLoadingViewController: NSViewController {
    
	// Outlets
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
	@IBOutlet weak var horizontalConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.activityIndicator.startAnimation(nil)
    }
	
	
	// MARK: - Accessors
	
	/// The top inset ensuring the loading content to appear centered.
	var topInset: CGFloat = 0 {
		didSet {
			self.horizontalConstraint.constant = (self.topInset / 2)
		}
	}
    
}

extension ReleaseNotesLoadingViewController: ReleaseNotesContentProtocol {
    
    typealias ReleaseNotesContentController = ReleaseNotesLoadingViewController
    
    static var StoryboardIdentifier: String {
        return "ReleaseNotesLoadingViewControllerIdentifier"
    }
    
}
