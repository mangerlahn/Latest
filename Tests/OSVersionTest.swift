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
