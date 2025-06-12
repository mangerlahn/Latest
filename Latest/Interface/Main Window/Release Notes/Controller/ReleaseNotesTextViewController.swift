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

	/// The inset of the text
	let contentInset: CGFloat = 14
	
    /// The view displaying the release notes
    @IBOutlet var textView: NSTextView!
    
    /// Updates the view with the given release notes
    func set(_ string: NSAttributedString) {
        // Format the release notes
        let text = self.format(string)
        
        self.textView.textStorage?.setAttributedString(text)
    }
    
    /// Updates the text views scroll insets
    func updateInsets(with inset: CGFloat) {
        let scrollView = self.textView.enclosingScrollView
        
        scrollView?.automaticallyAdjustsContentInsets = false
        scrollView?.contentInsets = NSEdgeInsetsMake(inset + contentInset, contentInset, contentInset, contentInset)
		scrollView?.scrollerInsets = NSEdgeInsetsMake(-contentInset, -contentInset, -contentInset, -contentInset)
        
        self.view.layout()
        scrollView?.documentView?.scroll(CGPoint(x: 0, y: -inset * 2))
    }
    
    // MARK: - Private Methods
    
    /**
     This method modifies the release notes to make them look uniform.
     All custom fonts and font sizes are removed for a more unified look. Specific styles like bold or italic parts as well as links are preserved.
     - parameter attributedString: The string to be formatted
     - returns: The formatted string
     */
    private func format(_ attributedString: NSAttributedString) -> NSAttributedString {
        let string = NSMutableAttributedString(attributedString: attributedString)
        let textRange = NSMakeRange(0, attributedString.length)
        let defaultFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        // Fix foreground color
        string.removeAttribute(.foregroundColor, range: textRange)
        string.addAttribute(.foregroundColor, value: NSColor.labelColor, range: textRange)
		
		// Remove background color
		string.removeAttribute(.backgroundColor, range: textRange)
        
		// Remove shadows
		string.removeAttribute(.shadow, range: textRange)
		
        // Reset font
        string.removeAttribute(.font, range: textRange)
        string.addAttribute(.font, value: defaultFont, range: textRange)
        
        // Copy traits like italic and bold
        attributedString.enumerateAttribute(NSAttributedString.Key.font, in: textRange, options: .reverse) { (fontObject, range, stopPointer) in
            guard let font = fontObject as? NSFont else { return }
            
            let traits = font.fontDescriptor.symbolicTraits
            let fontDescriptor = defaultFont.fontDescriptor.withSymbolicTraits(traits)
			if let font = NSFont(descriptor: fontDescriptor, size: defaultFont.pointSize) {
				string.addAttribute(.font, value: font, range: range)
			}
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
