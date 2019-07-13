//
//  AppUpdater.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 Delegate Protocol defining functions for changes of an app update
 */
protocol AppBundleDelegate {
    
    /**
     The version information of the AppUpdate changed. This can euther be the version or currentVersion parameter
     
     - parameter app: The app update with updated information
     */
    func appDidUpdateVersionInformation(_ app: AppBundle)
    
    /**
     The information provided by the app bundle was not sufficient. Therefore it makes no sense to further process this bundle.
     
     - parameter app: The app that failed to process
     */
    func didFailToProcess(_ app: AppBundle)
    
}

struct UpdateProgress {
	
	var error: Error? {
		didSet {
			self.notifyObservers()
		}
	}
	
	var state: UpdateOperation.ProgressState = .none {
		didSet {
			self.notifyObservers()
		}
	}
	
	typealias ObserverHandler = () -> Void
	
	private var observers = [NSObject: ObserverHandler]()
	
	mutating func addObserver(_ observer: NSObject, handler: @escaping ObserverHandler) {
		self.observers[observer] = handler
		
		// Call handler immediately to propagate initial state
		handler()
	}
	
	mutating func removeObserver(_ observer: NSObject) {
		self.observers.removeValue(forKey: observer)
	}
		
	func notifyObservers() {
		self.observers.forEach { (key: NSObject, handler: UpdateProgress.ObserverHandler) in
			handler()
		}
	}
	
}

/**
 The class containing information about one specific app. It holds information like its current version, name and path.
 */
class AppBundle : NSObject {
    
    /// The version currently present on the users computer
    let version: Version
    
    /// The display name of the app
	let name: String
	
	/// The bundle identifier of the app
	let bundleIdentifier: String
	
    /// The url of the app on the users computer
    let url: URL
    
    /// The delegate to be notified when app information changes
    var delegate : AppBundleDelegate?
    
    /// The newest information available for this app
    var newestVersion: UpdateInfo
	
	var updateProgress = UpdateProgress()
	
    /**
     Convenience initializer for creating an app object
	- parameter name: The name of the app
	- parameter bundleIdentifier: The bundle identifier of the app
    - parameter versionNumber: The current version number of the app
    - parameter buildNumber: The current build number of the app
     */
	init(appName: String, bundleIdentifier: String, versionNumber: String?, buildNumber: String?, url: URL) {
        self.version = Version(versionNumber ?? "", buildNumber ?? "")
        
        self.newestVersion = UpdateInfo()
        self.newestVersion.version = self.version
        
        self.name = appName
        self.url = url
		
		self.bundleIdentifier = bundleIdentifier
    }
    
    var updateAvailable: Bool {
        if self.newestVersion.version > self.version {
            return true
        }
        
        return false
    }
    
    
    // MARK: - Actions
    
    /// Opens the app and a given index
    func open() {
        NSWorkspace.shared.open(self.url)
    }
	
	/// Updates the app. This is a subclassing hook. The default implementation opens the app.
	func update() {
		self.open()
	}
    
    /// Reveals the app at a given index in Finder
    func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([self.url])
    }
	
	/// Returns an attributed string that highlights a given search query within this app's name.
	func highlightedName(for query: String?) -> NSAttributedString {
		let name = NSMutableAttributedString(string: self.name)
		
		if let queryString = query, let selectedRange = self.name.lowercased().range(of: queryString.lowercased()) {
			name.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: NSMakeRange(0, name.length))
			name.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(selectedRange, in: self.name))
		}
		
		return name
	}
	
	
    // MARK: - Debug
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(name)")
        print("Version number: \(self.version.versionNumber ?? "not given")")
        print("Build number: \(self.version.buildNumber ?? "not given")")
    }
    
}

// Version String Handling
extension AppBundle {
    
    /// A container holding the current and new version information
    struct DisplayableVersionInformation {
        
        /// The localized version of the app present on the computer
        var current: String {
            return String(format:  NSLocalizedString("Your version: %@", comment: "Current Version String"), "\(self.rawCurrent)")
        }
        
        /// The new available version of the app
        var new: String {
            return String(format: NSLocalizedString("New version: %@", comment: "New Version String"), "\(self.rawNew)")
        }
        
        fileprivate var rawCurrent: String
        fileprivate var rawNew: String
        
    }
    
    var localizedVersionInformation: DisplayableVersionInformation? {
        let info = self.newestVersion
        var versionInformation: DisplayableVersionInformation?
        
        if let v = self.version.versionNumber, let nv = info.version.versionNumber {
            versionInformation = DisplayableVersionInformation(rawCurrent: v, rawNew: nv)
        
            // If the shortVersion string is identical, but the bundle version is different
            // Show the Bundle version in brackets like: "1.3 (21)"
            if self.updateAvailable, v == nv, let v = self.version.buildNumber, let nv = info.version.buildNumber {
                versionInformation?.rawCurrent += " (\(v))"
                versionInformation?.rawNew += " (\(nv))"
            }
        } else if let v = self.version.buildNumber, let nv = info.version.buildNumber {
            versionInformation = DisplayableVersionInformation(rawCurrent: v, rawNew: nv)
        }
        
        return versionInformation
    }
    
}

extension AppBundle {
    /// Compares two apps on equality
    static func ==(lhs: AppBundle, rhs: AppBundle) -> Bool {
        return lhs.url == rhs.url
    }
}
