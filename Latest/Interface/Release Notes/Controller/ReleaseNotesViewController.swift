//
//  UpdateDetailsViewController.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import WebKit

/// The possible values when loading release notes content
fileprivate enum LoadReleaseNotesContent {
    case loading
    case error
    case text
}

/// The container for release notes content
fileprivate enum ReleaseNotesContent {
    
    /// The loading screen, presenting an activity indicator
    case loading(ReleaseNotesLoadingViewController?)
    
    /// The error screen, explaining what went wrong
    case error(ReleaseNotesErrorViewController?)
    
    /// The actual content
    case text(ReleaseNotesTextViewController?)
    
    var textController: ReleaseNotesTextViewController? {
        switch self {
        case .text(let controller):
            return controller
        default:
            return nil
        }
    }
    
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
    
    @IBOutlet weak var updateButton: NSButton!
    
    @IBOutlet weak var appNameTextField: NSTextField!
    @IBOutlet weak var appDateTextField: NSTextField!
    @IBOutlet weak var appCurrentVersionTextField: NSTextField!
    @IBOutlet weak var appNewVersionTextField: NSTextField!
    @IBOutlet weak var appIconImageView: NSImageView!
    
	/// The app currently presented
	private(set) var app: AppBundle? {
		willSet {
			if let app = self.app {
				UpdateQueue.shared.removeObserver(self, for: app)
			}
		}
		
		didSet {
			// Forward app
			self.progressViewController.app = self.app
			
			// Add ourselfs as observer to the app
			if let app = self.app {
				UpdateQueue.shared.addObserver(self, to: app) { _ in
					self.updateButtonAppearance()
				}
			}
		}
	}
    
    /// The current content presented on screen
    private var content: ReleaseNotesContent?

    // MARK: - View Lifecycle
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let constraint = NSLayoutConstraint(item: self.appInfoContentView!, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: -5)
        constraint.isActive = true

		self.setEmptyState()
		
		// Align progress view controller to update button
		self.progressViewController.leadingProgressAnchor.constraint(equalTo: self.updateButton.leadingAnchor).isActive = true
		self.progressViewController.displayCancelButton = false
	}
	
	func updateButtonAppearance() {
		if self.app?.isUpdating ?? false {
			self.updateButton.title = NSLocalizedString("Cancel", comment: "Cancel button title to cancel the update of an app")
			self.updateButton.action = #selector(cancelUpdate(_:))
		} else {
			self.updateButton.title = NSLocalizedString("Update", comment: "Update button title to update an app")
			self.updateButton.action = #selector(update(_:))
		}
		
		self.updateButton.target = self
	}
    
    
    // MARK: - Actions
    
    @objc func update(_ sender: NSButton) {
        self.app?.update()
    }
	
	@objc func cancelUpdate(_ sender: NSButton) {
		self.app?.cancelUpdate()
	}
    
    
    // MARK: - Display Methods
    
    /**
     Loads the content of the URL and displays them
     - parameter content: The content to be displayed
     */
    func display(content: Any?, for app: AppBundle?) {
		guard let app = app else {
			self.setEmptyState()
			return
		}
		
        self.display(app)
        
        switch content {
        case let url as URL:
            self.display(url: url, for: app)
        case let data as Data:
            self.update(with: data)
        case let html as String:
            self.display(html: html)
        case let error as Error:
            self.show(error)
        default:
            self.displayUnavailableReleaseNotes()
        }
    }
    
    func display(url: URL, for app: AppBundle) {
        // Delay the loading screen to avoid flickering
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { (_) in
            self.loadContent(.loading)
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            timer.invalidate()
            
            DispatchQueue.main.async {
                if let data = data, !data.isEmpty {
                    // Store the data
                    app.newestVersion.releaseNotes = data
                    
                        self.update(with: data)
                } else if let error = error {
                    self.show(error)
                }
            }
        }
        
        task.resume()
    }
    
    /**
     Displays the given HTML string. The HTML is currently not formatted in any way.
     - parameter html: The html to be displayed
     */
    func display(html: String) {
        guard let data = html.data(using: .utf16) else { return }
        self.update(with: NSAttributedString(html: data, documentAttributes: nil)!)
    }
    
    
    // MARK: - User Interface Stuff
    
    private func display(_ app: AppBundle) {
        self.appInfoBackgroundView.isHidden = false
        self.app = app
        self.appNameTextField.stringValue = app.name
        
        let info = app.newestVersion
        guard let versionInformation = app.localizedVersionInformation else { return }
        
        self.appCurrentVersionTextField.stringValue = versionInformation.current
        self.appNewVersionTextField.stringValue = versionInformation.new
        
        self.appNewVersionTextField.isHidden = !app.updateAvailable
        self.updateButton.isHidden = !app.updateAvailable
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        
        if let date = info.date {
            self.appDateTextField.stringValue = dateFormatter.string(from: date)
            self.appDateTextField.isHidden = false
        } else {
            self.appDateTextField.isHidden = true
        }
        
        IconCache.shared.icon(for: app) { (image) in
            self.appIconImageView.image = image
        }
        
        self.updateInsets()
    }
	
	private func setEmptyState() {
		// Prepare for empty state
		let description = NSLocalizedString("Select an app from the list to read its release notes.", comment: "Description of release notes empty state")
		let error = NSError(domain: "com.max-langer.addism", code: 1000, userInfo: [NSLocalizedDescriptionKey: description])
		self.show(error)
		self.content?.errorController?.titleTextField.stringValue = NSLocalizedString("No app selected.", comment: "Title of release notes empty state")

		self.appInfoBackgroundView.isHidden = true
		self.updateButton.isHidden = true
	}
    
    /**
     This method attempts to distinguish between HTML and Plain Text stored in the data. It converts the data to display it.
     - parameter data: The data to display, either HTML or plain text
     */
    private func update(with data: Data) {
        var options : [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.html]
        
        var string: NSAttributedString
        do {
            string = try NSAttributedString(data: data, options: options, documentAttributes: nil)
        } catch let error {
            self.show(error)
            return
        }

        // Having only one line means that the text was no HTML but plain text. Therefore we reinstantiate the attributed string as plain text
        // The initialization with HTML enabled removes all new lines
        // If anyone has a better idea for checking if the data is valid HTML or plain text, feel free to fix.
        if string.string.split(separator: "\n").count == 1 {
            options[.documentType] = NSAttributedString.DocumentType.plain
            
            do {
                string = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            } catch let error {
                self.show(error)
                return
            }
        }
        
        self.update(with: string)
    }
    
    private func loadContent(_ type: LoadReleaseNotesContent) {
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
        
        var constraints = [NSLayoutConstraint]()
        
        constraints.append(self.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 0))
        constraints.append(self.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0))
        constraints.append(self.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0))
        constraints.append(self.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0))
        
        NSLayoutConstraint.activate(constraints)
    }
    
    private func displayUnavailableReleaseNotes() {
        let description = NSLocalizedString("No release notes were found for this app.", comment: "Error message that no release notes were found")
        let error = NSError(domain: "com.max-langer.addism", code: 1000, userInfo: [NSLocalizedDescriptionKey: description])
        self.show(error)
    }
    
    private func initializeContent(of type: LoadReleaseNotesContent) {
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
    
    /**
     This method unwraps the data into a string, that is then formatted and displayed.
     - parameter data: The data to be displayed. It has to be some text or HTML, other types of data will result in an error message displayed to the user
     */
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
	
	/// The view controller displaying update progress
	private var progressViewController: UpdateProgressViewController {
		return self.children.compactMap { controller -> UpdateProgressViewController? in
			return controller as? UpdateProgressViewController
		}.first!
	}
    
}
