//
//  ReleaseNotesContentViewController.swift
//  Latest
//
//  Created by Max Langer on 12.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

fileprivate let ReleaseNotesTextParagraphCellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "ReleaseNotesTextParagraphCellIdentifier")

/// The controller displaying the actual release notes
class ReleaseNotesTextViewController: NSViewController {

    /// The view displaying the release notes
    @IBOutlet weak var textField: NSTextField!
    
    /// The table view holding the release notes
    @IBOutlet weak var tableView: NSTableView!
    
    /// The release notes, split up in paragraphs
    private var paragraphs = [NSAttributedString]()
    
    /// Updates the view with the given release notes
    func set(_ string: NSAttributedString) {
        // Format the release notes
        let text = self.format(string)
        let string = text.string as NSString
        
        // Get all paragraph ranges
        var location = 0
        var ranges = [NSRange]()
        repeat {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            ranges.append(paragraphRange)
            
            location = NSMaxRange(paragraphRange)
        } while (location < text.length)
        
        // Get the attributed substrings
        self.paragraphs = ranges.map { (range) -> NSAttributedString in
            //  Remove the last character, which is the paragraph delimiter. Leaving it in would result in an empty line in each table cell
            let paragraphRange = NSRange(location: range.location, length: range.length - 1)
            return text.attributedSubstring(from: paragraphRange)
        }
        
        // Update the view
        self.tableView.reloadData()
    }
    
    /// Updates the text views scroll insets
    func updateInsets(with inset: CGFloat) {
        let scrollView = self.tableView.enclosingScrollView
        
        scrollView?.automaticallyAdjustsContentInsets = false
        scrollView?.contentInsets.top = inset
        scrollView?.documentView?.scroll(CGPoint(x: 0, y: -inset))
    }
    
    // MARK: - Private Methods
    
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
        string.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        
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
    
}

extension ReleaseNotesTextViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.paragraphs.count
    }
    
}

extension ReleaseNotesTextViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: ReleaseNotesTextParagraphCellIdentifier, owner: self) as? NSTableCellView
        
        cell?.textField?.attributedStringValue = self.paragraphs[row]
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldTrackCell cell: NSCell, for tableColumn: NSTableColumn?, row: Int) -> Bool {
        return true
    }
    
}

extension ReleaseNotesTextViewController: ReleaseNotesContentProtocol {
    
    typealias ReleaseNotesContentController = ReleaseNotesTextViewController
    
    static var StoryboardIdentifier: String {
        return "ReleaseNotesTextViewControllerIdentifier"
    }
    
}
