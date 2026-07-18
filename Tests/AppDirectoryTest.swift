//
//  AppDirectoryTest.swift
//  Latest Tests
//
//  Created by Codex on 2026-03-15.
//

import XCTest
@testable import Latest

final class AppDirectoryTest: XCTestCase {

	func testInitFallsBackToSingleScanWhenDirectoryCannotBeObserved() throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
		defer {
			try? FileManager.default.removeItem(at: url)
		}

		let updateExpectation = expectation(description: "directory scan completes")

		let directory = AppDirectory(url: url, updateHandler: {
			updateExpectation.fulfill()
		}, descriptorProvider: { _ in (descriptor: -1, error: nil) })

		wait(for: [updateExpectation], timeout: 1)
		XCTAssertEqual(directory.bundles.count, 0)
	}

	func testNestedSubfolderChangesTriggerRefresh() throws {
		let fileManager = FileManager.default
		let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
			.appendingPathComponent("Latest-AppDirectoryTest-\(UUID().uuidString)", isDirectory: true)
		let nestedURL = rootURL.appendingPathComponent("Browsers", isDirectory: true)
		
		try fileManager.createDirectory(at: nestedURL, withIntermediateDirectories: true)
		defer { try? fileManager.removeItem(at: rootURL) }
		
		let initialScan = expectation(description: "Initial scan completes")
		let nestedChange = expectation(description: "Nested change triggers rescan")
		
		var callbackCount = 0
		var directory: AppDirectory?
		directory = AppDirectory(url: rootURL) {
			callbackCount += 1
			
			if callbackCount == 1 {
				initialScan.fulfill()
			}
			
			if directory?.bundles.contains(where: { $0.name == "Nested App" }) == true {
				nestedChange.fulfill()
			}
		}
		
		wait(for: [initialScan], timeout: 2)
		
		try Self.createAppBundle(
			named: "Nested App",
			identifier: "com.example.nested-app",
			at: nestedURL.appendingPathComponent("Nested App.app", isDirectory: true)
		)
		
		wait(for: [nestedChange], timeout: 5)
		XCTAssertEqual(directory?.bundles.count, 1)
		XCTAssertEqual(directory?.bundles.first?.name, "Nested App")
	}
	
	private static func createAppBundle(named name: String, identifier: String, at url: URL) throws {
		let fileManager = FileManager.default
		let contentsURL = url.appendingPathComponent("Contents", isDirectory: true)
		
		try fileManager.createDirectory(at: contentsURL, withIntermediateDirectories: true)
		
		let infoPlist: [String: Any] = [
			"CFBundleIdentifier": identifier,
			"CFBundleName": name,
			"CFBundlePackageType": "APPL",
			"CFBundleShortVersionString": "1.0",
			"CFBundleVersion": "1"
		]
		
		let data = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
		try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
	}
}
