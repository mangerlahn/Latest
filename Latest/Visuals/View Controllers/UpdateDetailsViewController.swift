//
//  UpdateDetailsViewController.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import WebKit

class UpdateDetailsViewController: NSViewController {

    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let constraint = NSLayoutConstraint(item: self.webView, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 3)
        constraint.isActive = true
    }
    
    func display(url: URL) {
        let request = URLRequest(url: url)
        self.webView.load(request)
    }
    
    func display(html: String) {
        self.webView.loadHTMLString(html, baseURL: nil)
    }
    
}
