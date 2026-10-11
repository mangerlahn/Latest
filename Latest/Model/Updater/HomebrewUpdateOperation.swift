//
//  HomebrewUpdateOperation.swift
//  Latest
//

import Foundation

/// The operation updating apps that are managed by a Homebrew cask.
///
/// Only casks Homebrew already manages are updated. Apps that were installed in another way keep opening the app as before.
class HomebrewUpdateOperation: UpdateOperation, @unchecked Sendable {
	
	/// The Homebrew cask token of the app.
	private let caskToken: String
	
	/// The running brew process, kept for cancellation.
	private var process: Process?
	
	init(bundleIdentifier: String, appIdentifier: App.Bundle.Identifier, caskToken: String) {
		self.caskToken = caskToken
		super.init(bundleIdentifier: bundleIdentifier, appIdentifier: appIdentifier)
	}
	
	
	// MARK: - Homebrew
	
	/// Where Homebrew is installed: Apple silicon or Intel default prefixes.
	private static let prefixes = ["/opt/homebrew", "/usr/local"]
	
	/// The location of the brew executable, if Homebrew is installed.
	static var brewURL: URL? {
		prefixes.map { URL(fileURLWithPath: $0).appendingPathComponent("bin/brew") }
			.first { FileManager.default.isExecutableFile(atPath: $0.path) }
	}
	
	/// Whether the token is a valid cask token and can safely be passed to brew.
	static func isValid(caskToken token: String) -> Bool {
		token.range(of: "^[a-z0-9][a-z0-9@._+-]*$", options: .regularExpression) != nil
	}
	
	/// Whether Homebrew already manages the cask. Homebrew keeps one folder per installed cask in its `Caskroom`.
	static func isInstalled(caskToken token: String, in caskrooms: [URL] = prefixes.map { URL(fileURLWithPath: $0).appendingPathComponent("Caskroom") }) -> Bool {
		guard isValid(caskToken: token) else { return false }
		return caskrooms.contains { FileManager.default.fileExists(atPath: $0.appendingPathComponent(token).path) }
	}
	
	/// Whether Latest can update the app through Homebrew.
	static func canUpdate(caskToken token: String) -> Bool {
		brewURL != nil && isInstalled(caskToken: token)
	}
	
	/// The arguments for upgrading the cask. `--greedy` includes apps that update themselves, which Latest lists as well.
	static func upgradeArguments(forCaskToken token: String) -> [String]? {
		isValid(caskToken: token) ? ["upgrade", "--cask", "--greedy", token] : nil
	}
	
	
	// MARK: - Operation Overrides
	
	override func execute() {
		super.execute()
		
		guard let brew = Self.brewURL, let arguments = Self.upgradeArguments(forCaskToken: caskToken) else {
			finish(with: LatestError.custom(title: NSLocalizedString("HomebrewNotInstalledError", value: "Homebrew is not installed", comment: "Error title when an app should be updated through Homebrew, but Homebrew is missing."), description: nil))
			return
		}
		
		progressState = .installing
		let process = Process()
		process.executableURL = brew
		process.arguments = arguments
		
		var environment = ProcessInfo.processInfo.environment
		environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
		environment["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
		environment["NONINTERACTIVE"] = "1"
		process.environment = environment
		
		let pipe = Pipe()
		process.standardOutput = pipe
		process.standardError = pipe
		self.process = process
		
		do {
			try process.run()
		} catch {
			finish(with: error)
			return
		}
		
		let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
		process.waitUntilExit()
		
		if isCancelled || process.terminationStatus == 0 {
			finish()
		} else {
			finish(with: LatestError.custom(title: NSLocalizedString("HomebrewUpdateFailedError", value: "Homebrew could not update this app", comment: "Error title when updating an app through Homebrew failed."), description: String(output.suffix(600))))
		}
	}
	
	override func cancel() {
		process?.terminate()
		super.cancel()
	}
	
}
