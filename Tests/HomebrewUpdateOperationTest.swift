//
//  HomebrewUpdateOperationTest.swift
//  LatestTests
//

import XCTest
@testable import Latest

final class HomebrewUpdateOperationTest: XCTestCase {
	
	private func caskroom(with tokens: [String]) throws -> URL {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("Caskroom-\(UUID().uuidString)")
		for token in tokens {
			try FileManager.default.createDirectory(at: url.appendingPathComponent(token), withIntermediateDirectories: true)
		}
		addTeardownBlock { try? FileManager.default.removeItem(at: url) }
		return url
	}
	
	func testRecognizesCasksThatHomebrewManages() throws {
		let caskroom = try caskroom(with: ["firefox", "powershell@preview"])
		XCTAssertTrue(HomebrewUpdateOperation.isInstalled(caskToken: "firefox", in: [caskroom]))
		XCTAssertTrue(HomebrewUpdateOperation.isInstalled(caskToken: "powershell@preview", in: [caskroom]))
		XCTAssertFalse(HomebrewUpdateOperation.isInstalled(caskToken: "zoom", in: [caskroom]), "Not installed through Homebrew")
	}
	
	func testChecksEveryCaskroom() throws {
		let first = try caskroom(with: [])
		let second = try caskroom(with: ["firefox"])
		XCTAssertTrue(HomebrewUpdateOperation.isInstalled(caskToken: "firefox", in: [first, second]))
	}
	
	func testBuildsTheUpgradeCommand() {
		XCTAssertEqual(HomebrewUpdateOperation.upgradeArguments(forCaskToken: "firefox"), ["upgrade", "--cask", "--greedy", "firefox"])
	}
	
	func testRejectsTokensThatCouldBeTakenForOptionsOrPaths() throws {
		for token in ["", "--force", "-x", "../firefox", "a/b", "fire fox", "a;b", "Firefox"] {
			XCTAssertFalse(HomebrewUpdateOperation.isValid(caskToken: token), "\(token) must not be passed to brew")
			XCTAssertNil(HomebrewUpdateOperation.upgradeArguments(forCaskToken: token))
		}
		let caskroom = try caskroom(with: ["firefox"])
		XCTAssertFalse(HomebrewUpdateOperation.isInstalled(caskToken: "../Caskroom/firefox", in: [caskroom]))
	}
	
}
