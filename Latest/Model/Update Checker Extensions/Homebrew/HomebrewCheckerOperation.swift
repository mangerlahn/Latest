//
//  HomebrewCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 12.03.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

import Cocoa

/// The operation for checking for updates via Homebrew.
class HomebrewCheckerOperation: StatefulOperation, UpdateCheckerOperation, @unchecked Sendable {
	
	static var sourceType: App.Source {
		return .none
	}
	
	/// The bundle to be checked for updates.
	private let bundle: App.Bundle
	
	/// The update fetched during the checking operation.
	fileprivate var update: App.Update?
	
	private let repository: UpdateRepository?
	
	static func canPerformUpdateCheck(forAppAt url: URL) -> Bool {
		return true
	}
		
	required init(with bundle: App.Bundle, repository: UpdateRepository?, completionBlock: @escaping UpdateCheckerCompletionBlock) {
		self.bundle =  bundle
		self.repository = repository
		
		super.init()
		
		self.completionBlock = {
			if let update = self.update {
				completionBlock(.success(update))
			} else {
				completionBlock(.failure(self.error ?? LatestError.updateInfoUnavailable))
			}
		}
	}
	
	
	// MARK: - Operation

	override func execute() {
		guard let repository else {
			self.finish()
			return
		}
		
		repository.updateInfo(for: bundle) { bundle, version, minimumOSVersion in
			defer { self.finish() }
			guard let version else { return }
			self.update = App.Update(app: bundle, remoteVersion: version, minimumOSVersion: minimumOSVersion, source: .homebrew, date: nil, releaseNotes: nil, updateAction: .external(label: bundle.name, block: { app in
				app.open()
			}))
		}
	}
	
}
