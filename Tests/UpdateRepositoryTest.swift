//
//  UpdateRepositoryTest.swift
//  LatestTests
//

import XCTest
@testable import Latest

final class UpdateRepositoryTest: XCTestCase {
	
	private func cask(_ token: String, name: String, app: String? = nil, zap: [String] = []) -> String {
		var artifacts = [String]()
		if let app { artifacts.append("{\"app\":[\"\(app)\"]}") }
		if !zap.isEmpty { artifacts.append("{\"zap\":[{\"trash\":[\(zap.map { "\"\($0)\"" }.joined(separator: ","))]}]}") }
		return "{\"token\":\"\(token)\",\"name\":[\"\(name)\"],\"version\":\"1.0\",\"depends_on\":{},\"artifacts\":[\(artifacts.joined(separator: ","))]}"
	}
	
	private lazy var repository: UpdateRepository = {
		let json = "[" + [
			cask("zoom", name: "Zoom", app: "zoom.us.app", zap: ["~/Library/Preferences/us.zoom.xos.plist"]),
			cask("zoom-for-it-admins", name: "Zoom for IT Admins", app: "zoom.us.app", zap: ["~/Library/Preferences/us.zoom.xos.plist"]),
			cask("microsoft-word", name: "Microsoft Word", app: "Microsoft Word.app", zap: ["~/Library/Preferences/com.microsoft.Word.plist"]),
			cask("microsoft-office", name: "Microsoft Office", app: "Microsoft Word.app", zap: ["~/Library/Preferences/com.microsoft.Word.plist"]),
			cask("raindropio", name: "Raindrop.io", app: "Raindrop.io.app", zap: ["~/Library/Preferences/com.apple.Safari.plist"]),
			cask("prism", name: "Prism", app: "Prism.app", zap: ["~/Library/Preferences/com.example.prism.plist"]),
			cask("foo-tool", name: "Foo Tool", app: "Tool.app", zap: ["~/Library/Preferences/com.foobar.tool.plist"]),
			cask("wordpresscom-studio", name: "WordPress.com Studio", app: "Studio.app", zap: ["~/Library/Preferences/com.electron.studio.plist"]),
			cask("googledrive", name: "Google Drive", app: "Google Drive.app", zap: ["~/Library/Preferences/com.google.drivefs.plist"])
		].joined(separator: ",") + "]"
		return UpdateRepository(entries: try! JSONDecoder().decode([UpdateRepository.Entry].self, from: Data(json.utf8)))
	}()
	
	private func bundle(_ file: String, id: String) -> App.Bundle {
		App.Bundle(version: Version(versionNumber: "1", buildNumber: nil), name: file, bundleIdentifier: id, fileURL: URL(fileURLWithPath: "/Applications/\(file)"), source: .none)
	}
	
	func testMatchesRenamedAppByBundleIdentifier() {
		XCTAssertEqual(repository.entry(for: bundle("Google Drive 2.app", id: "com.google.drivefs"))?.token, "googledrive")
	}
	
	func testPrefersBaseCaskOverVariants() {
		XCTAssertEqual(repository.entry(for: bundle("zoom.us.app", id: "us.zoom.xos"))?.token, "zoom")
	}
	
	func testIgnoresBundleIdentifierWithoutNameResemblance() {
		XCTAssertNil(repository.entry(for: bundle("Safari.app", id: "com.apple.Safari")))
		XCTAssertNil(repository.entry(for: bundle("Notes Pro.app", id: "com.example.prism")))
	}
	
	func testRejectsGenericNameMatchWithConflictingIdentifiers() {
		XCTAssertNil(repository.entry(for: bundle("Studio.app", id: "com.BrickLink.Studio")))
	}
	
	func testVendorComparisonUsesWholeComponents() {
		// "com.foo" must not count as the vendor of "com.foobar".
		XCTAssertNil(repository.entry(for: bundle("Tool.app", id: "com.foo.tool")))
	}
}
