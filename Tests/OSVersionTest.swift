//
//  VersionTest.swift
//  Latest Tests
//
//  Created by Max Langer on 14.11.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import XCTest
@testable import Latest

class OSVersionTest: XCTestCase {
	
	func testGenericOSVersion() throws {
		let version = try OperatingSystemVersion(string: "11.2.3")
		XCTAssertEqual(version.majorVersion, 11)
		XCTAssertEqual(version.minorVersion, 2)
		XCTAssertEqual(version.patchVersion, 3)
	}
	
	func testOnlyMajorOSVersion() throws {
		let version = try OperatingSystemVersion(string: "11.0")
		XCTAssertEqual(version.majorVersion, 11)
		XCTAssertEqual(version.minorVersion, 0)
		XCTAssertEqual(version.patchVersion, 0)
	}
	
	func testFourComponentOSVersion() throws {
		let version = try OperatingSystemVersion(string: "11.2.3.1")
		XCTAssertEqual(version.majorVersion, 11)
		XCTAssertEqual(version.minorVersion, 2)
		XCTAssertEqual(version.patchVersion, 3)
	}

	
	func testInvalidOSVersion() throws {
		XCTAssertThrowsError(try OperatingSystemVersion(string: ""))
		XCTAssertThrowsError(try OperatingSystemVersion(string: "Version"))
	}
	
}

final class AppDirectoryTest: XCTestCase {

	func testInitFallsBackToSingleScanWhenDirectoryCannotBeObserved() throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
		defer {
			try? FileManager.default.removeItem(at: url)
		}

		let updateExpectation = expectation(description: "directory scan completes")
		let observationError = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES), userInfo: nil)
		var reportedFailure: (url: URL, error: NSError)?

		let directory = AppDirectory(
			url: url,
			updateHandler: {
				updateExpectation.fulfill()
			},
			descriptorProvider: { _ in
				(-1, observationError)
			},
			observationErrorHandler: { failedURL, error in
				reportedFailure = (failedURL, error as NSError)
			}
		)

		wait(for: [updateExpectation], timeout: 1)
		XCTAssertEqual(directory.bundles.count, 0)
		XCTAssertEqual(reportedFailure?.url, url)
		XCTAssertEqual(reportedFailure?.error.domain, NSPOSIXErrorDomain)
		XCTAssertEqual(reportedFailure?.error.code, Int(EACCES))
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

final class AppDirectoryCountProviderTest: XCTestCase {

	func testCountDeduplicatesInFlightRequests() {
		let startedCollection = expectation(description: "collection starts once")
		let firstResult = expectation(description: "first request receives result")
		let secondResult = expectation(description: "second request receives result")
		let semaphore = DispatchSemaphore(value: 0)
		let url = URL(fileURLWithPath: "/tmp/Latest-AppDirectoryCountProviderTest", isDirectory: true)
		
		var invocationCount = 0
		let provider = AppDirectoryCountProvider(
			collectionQueue: DispatchQueue(label: "AppDirectoryCountProviderTest.collection"),
			bundleCounter: { _, _ in
				invocationCount += 1
				startedCollection.fulfill()
				semaphore.wait()
				return 3
			}
		)
		
		provider.count(for: url) { count in
			XCTAssertEqual(count, 3)
			firstResult.fulfill()
		}
		provider.count(for: url) { count in
			XCTAssertEqual(count, 3)
			secondResult.fulfill()
		}
		
		wait(for: [startedCollection], timeout: 1)
		XCTAssertEqual(invocationCount, 1)
		
		semaphore.signal()
		wait(for: [firstResult, secondResult], timeout: 1)
		XCTAssertEqual(invocationCount, 1)
	}
	
	func testCountUsesCachedResultAfterInitialScan() {
		let firstResult = expectation(description: "first request receives result")
		let secondResult = expectation(description: "second request receives cached result")
		let url = URL(fileURLWithPath: "/tmp/Latest-AppDirectoryCountProviderTest-cached", isDirectory: true)
		
		var invocationCount = 0
		let provider = AppDirectoryCountProvider(
			collectionQueue: DispatchQueue(label: "AppDirectoryCountProviderTest.cached"),
			bundleCounter: { _, _ in
				invocationCount += 1
				return 7
			}
		)
		
		provider.count(for: url) { count in
			XCTAssertEqual(count, 7)
			firstResult.fulfill()
		}
		
		wait(for: [firstResult], timeout: 1)
		XCTAssertEqual(invocationCount, 1)
		
		provider.count(for: url) { count in
			XCTAssertEqual(count, 7)
			secondResult.fulfill()
		}
		
		wait(for: [secondResult], timeout: 1)
		XCTAssertEqual(invocationCount, 1)
	}
}
