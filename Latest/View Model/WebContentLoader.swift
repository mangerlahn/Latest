//
//  WebContentLoader.swift
//  Latest
//
//  Created by Max Langer on 26.09.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

import WebKit

/// Object that loads websites for given URLs and returns their content as HTML.
class WebContentLoader: NSObject {
	
	/// Loads contents for the given URL.
	///
	/// The update handler may be called multiple times, if contents change. The caller is responsible for determining whether updates are still relevant.
	func load(from url: URL, contentUpdateHandler: @escaping(Result<String, Error>) -> Void) {
		currentUpdateHandler = contentUpdateHandler
		currentNavigation = webView.load(URLRequest(url: url))
	}


	// MARK: - Accessors
	
	/// The web view actually loading the web contents.
	///
	/// Required for some websites that use scripts to populate the sites contents.
	private lazy var webView: WKWebView = {
		let config = WKWebViewConfiguration()
		
		// Setup observation script
		let source = """
			let observer = new MutationObserver(function(mutations) {
			window.webkit.messageHandlers.updateHandler.postMessage("contentsUpdated");
			});
			
			observer.observe(document, { childList: true, subtree: true	});
		"""
		
		let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
		config.userContentController.addUserScript(script)
		config.userContentController.add(self, name: "updateHandler")
		
		// Setup web view
		let webView = WKWebView(frame: .zero, configuration: config)
		webView.navigationDelegate = self
		
		// Ensure the web view renders with full performance
		if #available(macOS 14.0, *) {
			webView.configuration.preferences.inactiveSchedulingPolicy = .none
		}
		
		return webView
	}()
	
	/// The current navigation object.
	private var currentNavigation: WKNavigation?
	
	/// The current update handler.
	private var currentUpdateHandler: ((Result<String, Error>) -> Void)?
	
	
	// MARK: - Utilities
	
	/// Forwards the current page contents to the caller of the load method.
	fileprivate func notifyContentUpdate() {
		webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { html, error in
			DispatchQueue.main.async {
				if let html = html as? String, !html.isEmpty {
					self.currentUpdateHandler?(.success(html))
				} else if let error = error {
					self.currentUpdateHandler?(.failure(error))
				}
			}
		}
	}
	
}

extension WebContentLoader: WKNavigationDelegate {
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		guard navigation == currentNavigation else { return }
		notifyContentUpdate()
	}
	
}

extension WebContentLoader: WKScriptMessageHandler {
	
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		guard message.name == "updateHandler" else { return }
		notifyContentUpdate()
	}
	
}
