//
//  UpdateChecker.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

/**
 Protocol that defines some methods on reporting the progress of the update checking process.
 */
protocol UpdateCheckerProgress : class {
    
	/// Indicates that the scan process has been started.
	func updateCheckerDidStartScanningForApps(_ updateChecker: UpdateChecker)

	/**
	The process of checking apps for updates has started
	- parameter numberOfApps: The number of apps that will be checked
	*/
	func updateChecker(_ updateChecker: UpdateChecker, didStartCheckingApps numberOfApps: Int)

	/// Indicates that a single app has been checked.
	func updateChecker(_ updateChecker: UpdateChecker, didCheckApp: AppBundle)

	/// Called after the update checker finished checking for updates.
	func updateCheckerDidFinishCheckingForUpdates(_ updateChecker: UpdateChecker)
	
}

/**
 UpdateChecker handles the logic for checking for updates.
 Each new method of checking for updates should be implemented in its own extension and then included in the `updateMethods` array
 */
class UpdateChecker {
    
    typealias UpdateCheckerCallback = (_ app: AppBundle) -> Void
        
	
	// MARK: - Initialization
	
	/// The shared instance of the update checker.
	static let shared = UpdateChecker()
	
	private init() {
		// Instantiate the folder listener to track changes to the Applications folder
		if let url = self.applicationURL {
			self.folderListener = FolderUpdateListener(url: url)
			self.folderListener?.resumeTracking()
		}
	}
	
	
	// MARK: - Update Checking
	
    /// The delegate for the progress of the entire update checking progress
    weak var progressDelegate : UpdateCheckerProgress?
	
	/// The data store updated apps should be passed to
	let dataStore = AppDataStore()
    
	/// Listens for changes in the Applications folder.
    private var folderListener : FolderUpdateListener?
    
    /// The url of the /Applications folder on the users Mac
    var applicationURL : URL? {
		let applicationURLList = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        
        return applicationURLList.first
    }
    
    /// The path of the users /Applications folder
    private var applicationPath : String {
        return applicationURL?.path ?? "/Applications/"
    }
        	
	/// The queue update checks are processed on.
	private let updateQueue = DispatchQueue(label: "UpdateChecker.updateQueue")
	
	/// The queue to run update checks on.
	let updateOperationQueue: OperationQueue = {
		let operationQueue = OperationQueue()
		
		// Allow 100 simultanious updates
		operationQueue.maxConcurrentOperationCount = 100
		
		return operationQueue
	}()
    
	/// Excluded subfolders that won't be checked.
	private static let excludedSubfolders = Set(["Setapp"])
	
	/// Starts the update checking process
	func run() {
		// An update check is still ongoing, skip another round
		guard self.updateOperationQueue.operationCount == 0 else {
			return
		}
                
		self.progressDelegate?.updateCheckerDidStartScanningForApps(self)
		
		DispatchQueue.global().async {
			self.runUpdateCheck()
		}
	}
	
    private func runUpdateCheck() {
		guard let url = self.applicationURL, let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isApplicationKey]) else { return }
        		
		var updateOperations = [Operation]()
        
        while let url = enumerator.nextObject() as? URL {
			// Check for subfolders that should be skipped
			if Self.excludedSubfolders.contains(url.lastPathComponent) {
				enumerator.skipDescendants()
				continue
			}
			
			// Verify the given url points to an app, otherwise investigate descendants
			guard let value = try? url.resourceValues(forKeys: [.isApplicationKey]), value.isApplication ?? false else {
				if !url.pathExtension.isEmpty {
					enumerator.skipDescendants()
				}
				
				continue
			}
			
			// Create an update check operation from the url if possible
			if let operation = self.updateCheckOperation(forAppAt: url) {
				updateOperations.append(operation)
			}
			            
			// Don't check an app-containers subfolders
            enumerator.skipDescendants()
        }
		
		self.performUpdateCheck(with: updateOperations)
	}
	
	private func updateCheckOperation(forAppAt url: URL) -> Operation? {
		let contentURL = url.appendingPathComponent("Contents")
		
		// Check, if the changed file was the Info.plist
		guard let plists = try? FileManager.default.contentsOfDirectory(at: contentURL, includingPropertiesForKeys: nil)
			.filter({ $0.pathExtension == "plist" }),
			let plistURL = plists.first,
			let infoDict = NSDictionary(contentsOf: plistURL),
			let version = infoDict["CFBundleShortVersionString"] as? String,
			let buildNumber = infoDict["CFBundleVersion"] as? String else {
				return nil
		}
		
		return ([MacAppStoreUpdateCheckerOperation.self, SparkleUpdateCheckerOperation.self] as [UpdateCheckerOperation.Type]).reduce(nil) { (result, operationType) -> Operation? in
			if result == nil {
				return operationType.init(withAppURL: url, version: version, buildNumber: buildNumber, completionBlock: self.didCheck)
			}
			
			return result
		}
	}
	
	private func performUpdateCheck(with operations: [Operation]) {
		assert(!Thread.current.isMainThread, "Must not be called on main thread.")
		
		// Inform delegate of update check
		DispatchQueue.main.async {
			self.progressDelegate?.updateChecker(self, didStartCheckingApps: operations.count)
		}
		
		self.dataStore.beginUpdates()

		// Start update check
		self.updateOperationQueue.addOperations(operations, waitUntilFinished: true)
			
		DispatchQueue.main.async {
			// Update Checks finished
			self.progressDelegate?.updateCheckerDidFinishCheckingForUpdates(self)
		}
	}
    
    private func didCheck(_ app: AppBundle) {
		// Ensure serial access to the data store
		self.updateQueue.sync {
			self.dataStore.update(app)
			
			DispatchQueue.main.async {
				self.progressDelegate?.updateChecker(self, didCheckApp: app)
			}
		}
    }
}
