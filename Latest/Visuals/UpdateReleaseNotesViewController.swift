//
//  UpdateDetailsViewController.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import WebKit

/**
 This is a super rudimentary implementation of an release notes viewer.
 It can open urls or display HTML strings right away.
 */
class UpdateReleaseNotesViewController: NSViewController {
    
    private(set) var app: AppBundle?
    
    /// The view displaying the release notes
    @IBOutlet weak var textField: NSTextField!
    
    @IBOutlet weak var appInfoBackgroundView: NSVisualEffectView!
    @IBOutlet weak var appInfoContentView: NSStackView!
    
    @IBOutlet weak var appNameTextField: NSTextField!
    @IBOutlet weak var appDateTextField: NSTextField!
    @IBOutlet weak var appCurrentVersionTextField: NSTextField!
    @IBOutlet weak var appNewVersionTextField: NSTextField!
    @IBOutlet weak var appIconImageView: NSImageView!
    
    // MARK: - View Lifecycle
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let constraint = NSLayoutConstraint(item: self.appInfoContentView, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 0)
        constraint.isActive = true
    }
    
    
    // MARK: - Actions
    
    @IBAction func update(_ sender: NSButton) {
        self.app?.open()
    }
    
    
    // MARK: - Display Methods
    
    /**
     Loads the content of the URL and displays them
     - parameter content: The content to be displayed
     */
    func display(content: Any, for app: AppBundle) {
        self.display(app)
        
        switch content {
        case let url as URL:
            self.display(url: url)
        case let data as Data:
            self.update(with: data)
        case let html as String:
            self.display(html: html)
        default:
            ()
        }
    }
    
    func display(url: URL) {
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            
            if let data = data {
                DispatchQueue.main.async {
                    self.update(with: data)
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
        self.update(with: data)
    }
    
    
    // MARK: - User Interface Stuff
    
    private func display(_ app: AppBundle) {
        self.app = app
        self.appNameTextField.stringValue = app.name
        
        let info = app.newestVersion!
        var version = ""
        var newVersion = ""
        
        if let v = app.version.versionNumber, let nv = info.version.versionNumber {
            version = v
            newVersion = nv
            
            // If the shortVersion string is identical, but the bundle version is different
            // Show the Bundle version in brackets like: "1.3 (21)"
            if version == newVersion, let v = app.version?.buildNumber, let nv = info.version.buildNumber {
                version += " (\(v))"
                newVersion += " (\(nv))"
            }
        } else if let v = app.version.buildNumber, let nv = info.version.buildNumber {
            version = v
            newVersion = nv
        }
        
        self.appCurrentVersionTextField.stringValue = String(format:  NSLocalizedString("Your version: %@", comment: "Current Version String"), "\(version)")
        self.appNewVersionTextField.stringValue = String(format: NSLocalizedString("New version: %@", comment: "New Version String"), "\(newVersion)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        
        if let date = info.date {
            self.appDateTextField.stringValue = dateFormatter.string(from: date)
            self.appDateTextField.isHidden = false
        } else {
            self.appDateTextField.isHidden = true
        }
        
        DispatchQueue.main.async {
            self.appIconImageView.image = NSWorkspace.shared.icon(forFile: app.url!.path)
        }
        
        self.updateInsets()
    }
    
    /**
     This method unwraps the data into a string, that is then formatted and displayed.
     - parameter data: The data to be displayed. It has to be some text or HTML, other types of data will result in an error message displayed to the user
     */
    private func update(with data: Data) {
        guard let string = NSAttributedString(html: data, documentAttributes: nil) else { return }
        
        self.textField.attributedStringValue = self.format(string)
        self.updateInsets()
        self.view.layout()
        self.textField.enclosingScrollView?.scrollToVisible(.zero)
    }

    /**
     This method manipulates the release notes to make them look uniform.
     All custom fonts and font sizes are removed for a more unified look. Specific styles like bold or italic parts as well as links are preserved.
     - parameter attributedString: The string to be formatted
     - returns: The formatted string
     */
    private func format(_ attributedString: NSAttributedString) -> NSAttributedString {
        let string = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSMakeRange(0, attributedString.length)
        let defaultFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        /// Remove all color
        string.removeAttribute(.foregroundColor, range: fullRange)
        
        /// Reset font
        string.removeAttribute(.font, range: fullRange)
        string.addAttribute(.font, value: defaultFont, range: fullRange)
        
        // Copy traits like italic and bold
        attributedString.enumerateAttribute(NSAttributedString.Key.font, in: fullRange, options: .reverse) { (fontObject, range, stopPointer) in
            guard let font = fontObject as? NSFont else { return }
            
            let traits = font.fontDescriptor.symbolicTraits
            let fontDescriptor = defaultFont.fontDescriptor.withSymbolicTraits(traits)
            
            string.addAttribute(.font, value: NSFont(descriptor: fontDescriptor, size: defaultFont.pointSize)!, range: range)
        }

        return string
    }
    
    private func updateInsets() {
        let inset = self.appInfoBackgroundView.frame.size.height
        self.textField.superview?.enclosingScrollView?.contentInsets.top = inset
    }
    
}
