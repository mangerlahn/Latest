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

	func testMacAppStoreWorkaroundVersions() {
		XCTAssertFalse(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 14, minorVersion: 8, patchVersion: 1)))
		XCTAssertTrue(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 14, minorVersion: 8, patchVersion: 2)))
		XCTAssertTrue(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 14, minorVersion: 8, patchVersion: 3)))
		XCTAssertFalse(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 15, minorVersion: 7, patchVersion: 1)))
		XCTAssertTrue(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 15, minorVersion: 7, patchVersion: 2)))
		XCTAssertTrue(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 15, minorVersion: 8, patchVersion: 0)))
		XCTAssertFalse(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)))
		XCTAssertTrue(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0)))
		XCTAssertTrue(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 26, minorVersion: 2, patchVersion: 0)))
		XCTAssertTrue(MacAppStoreUpdateCheckerOperation.requiresExternalUpdateWorkaround(for: OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)))
	}
	
}
