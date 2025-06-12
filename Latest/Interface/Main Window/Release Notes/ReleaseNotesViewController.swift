//
//  UpdateDetailsViewController.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import WebKit

/// The container for release notes content
fileprivate enum ReleaseNotesContent {
	
	/// The possible values when loading release notes content
	enum ContentType {
		
		/// The release notes view should display a loading indicator.
		case loading
		
		/// The release notes should display an error.
		case error
		
		/// Release notes contents should be displayed.
		case text
		
		/// Whether the currently displayed content is scrollable.
		var isScrollable: Bool {
			switch self {
				case .loading, .error:
					return false
					
				case .text:
					return true
			}
		}
	}
    
    /// The loading screen, presenting an activity indicator
    case loading(ReleaseNotesLoadingViewController?)
    
    /// The error screen, explaining what went wrong
    case error(ReleaseNotesErrorViewController?)
    
    /// The actual content
    case text(ReleaseNotesTextViewController?)
    
	/// Exposes the view controller holding the release notes, if available.
    var textController: ReleaseNotesTextViewController? {
        switch self {
        case .text(let controller):
            return controller
        default:
            return nil
        }
    }
    
	/// Exposes the view controller indicating a loading action, if available.
	var loadingController: ReleaseNotesLoadingViewController? {
        switch self {
        case .loading(let controller):
            return controller
        default:
            return nil
        }
	}
	
	/// Exposes the view controller holding an error, if available.
    var errorController: ReleaseNotesErrorViewController? {
        switch self {
        case .error(let controller):
            return controller
        default:
            return nil
        }
    }
    
    /// Returns the current view controller
    var controller: NSViewController? {
        switch self {
        case .loading(let controller):
            return controller
        case .error(let controller):
            return controller
        case .text(let controller):
            return controller
        }
    }
}

/**
 This is a super rudimentary implementation of an release notes viewer.
 It can open urls or display HTML strings right away.
 */
class ReleaseNotesViewController: NSViewController {
    
    @IBOutlet weak var appInfoBackgroundView: NSVisualEffectView!
    @IBOutlet weak var appInfoContentView: NSStackView!
    
    @IBOutlet weak var updateButton: UpdateButton!
	@IBOutlet weak var externalUpdateLabel: NSTextField!
    
    @IBOutlet weak var appNameTextField: NSTextField!
    @IBOutlet weak var appDateTextField: NSTextField!
    @IBOutlet weak var appVersionTextField: NSTextField!
    @IBOutlet weak var appIconImageView: NSImageView!
	
	/// Button indicating the support state of a given app.
	@IBOutlet private weak var supportStateButton: NSButton!
	
	private let releaseNotesProvider = ReleaseNotesProvider()
    
	/// The app currently presented
	private(set) var app: App? {
		didSet {
			// Forward app
			self.updateButton.app = self.app
		}
	}
    
    /// The current content presented on screen
    private var content: ReleaseNotesContent?

    // MARK: - View Lifecycle
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let constraint = NSLayoutConstraint(item: self.appInfoContentView!, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 0)
        constraint.isActive = true

		self.setEmptyState()
	}
	
    
    
    // MARK: - Actions
    
    @objc func update(_ sender: NSButton) {
        self.app?.performUpdate()
    }
	
	@objc func cancelUpdate(_ sender: NSButton) {
		self.app?.cancelUpdate()
	}
    
    
    // MARK: - Display Methods
    
    /**
     Loads the content of the URL and displays them
     - parameter content: The content to be displayed
     */
	func display(releaseNotesFor app: App?) {
		guard let app = app else {
			self.setEmptyState()
			return
		}
		
        self.display(app)

		// Delay the loading screen to avoid flickering
		let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { (_) in
			self.loadContent(.loading)
		}
		releaseNotesProvider.releaseNotes(for: app) { result in
			timer.invalidate()

			switch result {
				case .success(let releaseNotes):
					self.update(with: releaseNotes)
				case .failure(let error):
					self.show(error)
			}
		}
    }
	
    
    // MARK: - User Interface Stuff
	
	/// Date formatter used to display the apps update date.
	private lazy var appDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .none
		
		return dateFormatter
	}()
    
    private func display(_ app: App) {
		// Update header
        self.appInfoBackgroundView.isHidden = false
        self.app = app
        self.appNameTextField.stringValue = app.name
        
		// Version Information
        if let versionInformation = app.localizedVersionInformation {
			self.appVersionTextField.stringValue = versionInformation.combined(includeNew: app.updateAvailable)
		}
		
		// Support state
		self.supportStateButton.isHidden = !(AppListSettings.shared.includeUnsupportedApps || AppListSettings.shared.includeAppsWithLimitedSupport)
		if !self.supportStateButton.isHidden {
			self.supportStateButton.title = app.source.supportState.compactLabel
			self.supportStateButton.image = app.source.supportState.statusImage
		}
		
		// Icon
		IconCache.shared.icon(for: app) { (image) in
			self.appIconImageView.image = image
		}
		
		// Date
		if let date = app.latestUpdateDate {
            self.appDateTextField.stringValue = appDateFormatter.string(from: date)
            self.appDateTextField.isHidden = false
        } else {
            self.appDateTextField.isHidden = true
        }
		
		// Update Action
		if app.updateAvailable, let name = app.externalUpdaterName {
			externalUpdateLabel.stringValue = String(format: NSLocalizedString("ExternalUpdateActionWithAppName", comment: "An explanatory text indicating where the update will be performed. The placeholder will be filled with the name of the external updater (App Store, App Name). The text will appear below the Update button, so that it reads: \"Update in XY\""), name)
		} else {
			externalUpdateLabel.stringValue = ""
		}
        
        
        self.updateInsets()
    }
	
	private func setEmptyState() {
		self.app = nil
		
		// Prepare for empty state
		let error = LatestError.custom(title: NSLocalizedString("NoAppSelectedTitle", comment: "Title of release notes empty state"),
									   description: NSLocalizedString("NoAppSelectedDescription", comment: "Description of release notes empty state"))
		self.show(error)

		self.appInfoBackgroundView.isHidden = true
	}
        
	private func loadContent(_ type: ReleaseNotesContent.ContentType) {
        // Remove the old content
        if let oldController = self.content?.controller {
            oldController.view.removeFromSuperview()
            oldController.removeFromParent()
        }
            
        self.initializeContent(of: type)
        
        guard let controller = self.content?.controller else { return }
        let view = controller.view
        
        self.addChild(controller)
        self.view.addSubview(view, positioned: .below, relativeTo: self.view.subviews.first)
        view.translatesAutoresizingMaskIntoConstraints = false
        
		let topAnchor = type.isScrollable || self.app == nil ? self.view.topAnchor : appInfoBackgroundView.bottomAnchor
		
        var constraints = [NSLayoutConstraint]()
        
        constraints.append(topAnchor.constraint(equalTo: view.topAnchor, constant: 0))
        constraints.append(self.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0))
        constraints.append(self.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0))
        constraints.append(self.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0))
        
        NSLayoutConstraint.activate(constraints)
		
		self.updateInsets()
    }
        
    private func initializeContent(of type: ReleaseNotesContent.ContentType) {
        switch type {
        case .loading:
            let controller = ReleaseNotesLoadingViewController.fromStoryboard()
            self.content = .loading(controller)
        case .error:
            let controller = ReleaseNotesErrorViewController.fromStoryboard()
            self.content = .error(controller)
        case .text:
            let controller = ReleaseNotesTextViewController.fromStoryboard()
            self.content = .text(controller)
        }
    }
    
    /// This method unwraps the data into a string, that is then formatted and displayed.
	///
	/// - parameter data: The data to be displayed. It has to be some text or HTML, other types of data will result in an error message displayed to the user
    private func update(with string: NSAttributedString) {
        self.loadContent(.text)
        self.content?.textController?.set(string)
        self.updateInsets()
    }
    
    /// Updates the top inset of the release notes scrollView
    private func updateInsets() {
        let inset = self.appInfoBackgroundView.frame.size.height
        self.content?.textController?.updateInsets(with: inset)
    }
    
    /// Switches the content to error and displays the localized error
    private func show(_ error: Error) {
        self.loadContent(.error)
        self.content?.errorController?.show(error)
    }
	
	// MARK: - Navigation
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "presentSupportStateInfo":
			guard let controller = segue.destinationController as? SupportStatusInfoViewController else { fatalError("Unknown controller for segue \(String(describing: segue.identifier))")}
			controller.app = self.app
		default:
			break
		}
	}
	    
}
