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
class UpdateDetailsViewController: NSViewController {

    /// The web view displaying the release notes
    @IBOutlet weak var webView: WKWebView!
    
    
    // MARK: - View Lifecycle
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let constraint = NSLayoutConstraint(item: self.webView, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 3)
        constraint.isActive = true
    }
    
    
    // MARK: - Display Methods
    
    /**
     Loads the content of the URL and displays them
     - parameter url: The url to be displayed
     */
    func display(url: URL) {
        let request = URLRequest(url: url)
        self.webView.load(request)
    }
    
    /**
     Displays the given HTML string. The HTML is currently not formatted in any way.
     - parameter html: The html to be displayed
     */
    func display(html: String) {
        self.webView.loadHTMLString(html, baseURL: nil)
    }
    
}
