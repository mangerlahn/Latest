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
        self.update(with: NSAttributedString(html: data, documentAttributes: nil)!)
    }
    
    
    // MARK: - User Interface Stuff
    
    private func display(_ app: AppBundle) {
        self.app = app
        self.appNameTextField.stringValue = app.name
        
        guard let info = app.newestVersion, let versionInformation = app.localizedVersionInformation else { return }
        
        self.appCurrentVersionTextField.stringValue = versionInformation.current
        self.appNewVersionTextField.stringValue = versionInformation.new
        
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
    
    /**
     This method attempts to distinguish between HTML and Plain Text stored in the data. It converts the data to display it.
     - parameter data: The data to display, either HTML or plain text
     */
    private func update(with data: Data) {
        var options : [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.html]
        
        guard var string = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else { return }
        
        // Having only one line means that the text was no HTML but plain text. Therefore we reinstantiate the attributed string as plain text
        // The initialization with HTML enabled removes all new lines
        // If anyone has a better idea for checking if the data is valid HTML or plain text, feel free to fix.
        if string.string.split(separator: "\n").count == 1 {
            options[.documentType] = NSAttributedString.DocumentType.plain
            guard let tempString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else { return }
            string = tempString
        }
        
        self.update(with: string)
    }
    
    /**
     This method unwraps the data into a string, that is then formatted and displayed.
     - parameter data: The data to be displayed. It has to be some text or HTML, other types of data will result in an error message displayed to the user
     */
    private func update(with string: NSAttributedString) {
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
    
    /// Updates the top inset of the release notes scrollView
    private func updateInsets() {
        let inset = self.appInfoBackgroundView.frame.size.height
        self.textField.superview?.enclosingScrollView?.contentInsets.top = inset
    }
    
}
