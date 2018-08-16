//
//  ReleaseNotesContentViewController.swift
//  Latest
//
//  Created by Max Langer on 12.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

/// The controller displaying the actual release notes
class ReleaseNotesTextViewController: NSViewController {

    /// The view displaying the release notes
    @IBOutlet weak var textField: NSTextField!
    
    /// Sets the string in the text view
    func set(_ string: NSAttributedString) {
        self.textField.attributedStringValue = self.format(string)
    }
    
    /// Updates the text views scroll insets
    func updateInsets(with inset: CGFloat) {
        self.textField.superview?.enclosingScrollView?.contentInsets.top = inset
        
        self.view.layout()
        
        let view = self.textField.enclosingScrollView?.documentView
        view?.scroll(CGPoint(x: 0, y: (view?.bounds.size.height ?? 0.0) + inset))
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

extension ReleaseNotesTextViewController: ReleaseNotesContentProtocol {
    
    typealias ReleaseNotesContentController = ReleaseNotesTextViewController
    
    static var StoryboardIdentifier: String {
        return "ReleaseNotesTextViewControllerIdentifier"
    }
    
}
