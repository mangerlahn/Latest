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
		}, descriptorProvider: { _ in -1 })

		wait(for: [updateExpectation], timeout: 1)
		XCTAssertEqual(directory.bundles.count, 0)
	}

}
