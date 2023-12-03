//
//  VersionTest.swift
//  Latest Tests
//
//  Created by Max Langer on 14.11.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import XCTest
@testable import Latest

class VersionTest: XCTestCase {

    func testInitialization() {
        // Simple test
		var version = Version(versionNumber: "2.1.5", buildNumber: "215")
        
        XCTAssertEqual(version.versionNumber, "2.1.5")
        XCTAssertEqual(version.buildNumber, "215")
        
        // Nil test
		version = Version(versionNumber: nil, buildNumber: nil)
        XCTAssertNil(version.versionNumber)
        XCTAssertNil(version.buildNumber)
    }
	
	func testEmptyVersion() {
		XCTAssertTrue(Version(versionNumber: nil, buildNumber: nil).isEmpty)
		XCTAssertTrue(Version(versionNumber: nil, buildNumber: "").isEmpty)
		XCTAssertTrue(Version(versionNumber: "", buildNumber: "").isEmpty)
		XCTAssertTrue(Version(versionNumber: nil, buildNumber: ".").isEmpty)
		XCTAssertTrue(Version(versionNumber: "\n", buildNumber: nil).isEmpty)
		
		XCTAssertFalse(Version(versionNumber: "1", buildNumber: nil).isEmpty)
		XCTAssertFalse(Version(versionNumber: nil, buildNumber: "1").isEmpty)
		XCTAssertFalse(Version(versionNumber: "1.2", buildNumber: "123").isEmpty)
	}
    
    
    // MARK: - Right Comparison
    
    func testRightComparison() {
        // If bundle is available, check for the bundle
        
        // Should check the bundle version
		var v1 = Version(versionNumber: "2.1.5", buildNumber: "312")
		var v2 = Version(versionNumber: "2.1.6d12", buildNumber: "215")
        self.newer(v1, v2)
        
        // Should check the version
		v1 = Version(versionNumber: "2.1.5", buildNumber: nil)
		v2 = Version(versionNumber: "2.2.6", buildNumber: "216")
        self.older(v1, v2)
        
        // Should check the version
		v1 = Version(versionNumber: "2.1.5", buildNumber: "215")
		v2 = Version(versionNumber: "2.2.6", buildNumber: nil)
        self.older(v1, v2)
        
        // Should check the version
		v1 = Version(versionNumber: "2.1.5", buildNumber: nil)
		v2 = Version(versionNumber: "2.2.6", buildNumber: nil)
        self.older(v1, v2)
    }
    
    
    // MARK: - Bundle Checking
    
    func testOlderBundle() {
		var v1 = Version(versionNumber: "2.1.5", buildNumber: "215")
		var v2 = Version(versionNumber: "2.1.6", buildNumber: "216")
        self.older(v1, v2)
        
		v1 = Version(versionNumber: "2.1.5", buildNumber: "215a")
		v2 = Version(versionNumber: "2.2.6", buildNumber: "216b")
        self.older(v1, v2)
    }
    
    func testEqualBundle() {
		let v1 = Version(versionNumber: "2.1.5", buildNumber: "215")
		let v2 = Version(versionNumber: "2.1.5", buildNumber: "215")
        self.equal(v1, v2)
    }
    
    func testNewerBundle() {
		var v1 = Version(versionNumber: "2.0.6", buildNumber: "217")
		var v2 = Version(versionNumber: "2.1.5", buildNumber: "216")
        self.newer(v1, v2)
        
		v1 = Version(versionNumber: "2.1.6", buildNumber: "217a")
		v2 = Version(versionNumber: "2.2.4", buildNumber: "216b")
        self.newer(v1, v2)
    }
    
    // MARK: - Version Checking
    
    func testOlderVersionSimple() {
		var v1 = Version(versionNumber: "2.1.5", buildNumber: nil)
		var v2 = Version(versionNumber: "2.1.6", buildNumber: "216")
        self.older(v1, v2)
        
		v1 = Version(versionNumber: "2.1.5", buildNumber: "215")
		v2 = Version(versionNumber: "2.2.6", buildNumber: nil)
        self.older(v1, v2)
        
		v1 = Version(versionNumber: "2.1.5", buildNumber: nil)
		v2 = Version(versionNumber: "3.1.6", buildNumber: nil)
        self.older(v1, v2)
    }

    func testEqualVersionSimple() {
		var v1 = Version(versionNumber: "2.1.5", buildNumber: nil)
		var v2 = Version(versionNumber: "2.1.5", buildNumber: "215")
        self.equal(v1, v2)

		v1 = Version(versionNumber: "2.2.6", buildNumber: "215")
		v2 = Version(versionNumber: "2.2.6", buildNumber: nil)
        self.equal(v1, v2)

		v1 = Version(versionNumber: "3.1.6", buildNumber: nil)
		v2 = Version(versionNumber: "3.1.6", buildNumber: nil)
        self.equal(v1, v2)
    }

    func testNewerVersionSimple() {
		var v1 = Version(versionNumber: "2.1.6", buildNumber: nil)
		var v2 = Version(versionNumber: "2.1.5", buildNumber: "216")
        self.newer(v1, v2)

		v1 = Version(versionNumber: "2.3.6", buildNumber: "215")
		v2 = Version(versionNumber: "2.2.4", buildNumber: nil)
        self.newer(v1, v2)

		v1 = Version(versionNumber: "4.1.5", buildNumber: nil)
		v2 = Version(versionNumber: "3.1.6", buildNumber: nil)
        self.newer(v1, v2)
    }
    
    func testOlderVersion() {
		let v1 = Version(versionNumber: "2.1.5", buildNumber: nil)
		let v2 = Version(versionNumber: "2.1.6", buildNumber: "216")
        self.older(v1, v2)
    }
    
    func testEqualVersion() {
		var v1 = Version(versionNumber: "2.1.5", buildNumber: nil)
		var v2 = Version(versionNumber: "2.1.5.0", buildNumber: "215")
        self.equal(v1, v2)
        
		v1 = Version(versionNumber: "2.2.6.0", buildNumber: "215")
		v2 = Version(versionNumber: "2.2.6", buildNumber: nil)
        self.equal(v1, v2)
        
		v1 = Version(versionNumber: "2.2.6", buildNumber: nil)
		v2 = Version(versionNumber: "2.2.6", buildNumber: nil)
        self.equal(v1, v2)
    }
    
    func testNewerVersion() {
		var v1 = Version(versionNumber: "3.1.5", buildNumber: nil)
		var v2 = Version(versionNumber: "2.1.6", buildNumber: "216")
        self.newer(v1, v2)
        
		v1 = Version(versionNumber: "3.1.5", buildNumber: "215")
		v2 = Version(versionNumber: "2.2.6", buildNumber: nil)
        self.newer(v1, v2)
    }
	
	func testNumeralSystems() {
		// Western arabic numerals
		var v1 = Version(versionNumber: "3.1.5", buildNumber: nil)
		var v2 = Version(versionNumber: "2.1.6", buildNumber: "216")
		self.newer(v1, v2)
		
		// Eastern arabic numerals
		v1 = Version(versionNumber: "٣.١.٥", buildNumber: "٢١٥")
		v2 = Version(versionNumber: "٢.٢.٦", buildNumber: nil)
		self.newer(v1, v2)
		
		// Indian numerals
		v1 = Version(versionNumber: "३.१.५", buildNumber: "२१७")
		v2 = Version(versionNumber: "२.१.६", buildNumber: nil)
		self.newer(v1, v2)
	}
	
	
    // MARK: - Helper Methods
    
    private func older(_ v1: Version, _ v2: Version) {
        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v1 <= v2)
        XCTAssertTrue(v1 != v2)
        XCTAssertFalse(v1 == v2)
        XCTAssertFalse(v1 >= v2)
        XCTAssertFalse(v1 > v2)
    }
    
    private func equal(_ v1: Version, _ v2: Version) {
        XCTAssertTrue(v1 >= v2)
        XCTAssertTrue(v1 <= v2)
        XCTAssertTrue(v1 == v2)
        XCTAssertFalse(v1 != v2)
        XCTAssertFalse(v1 < v2)
        XCTAssertFalse(v1 > v2)
    }
    
    private func newer(_ v1: Version, _ v2: Version) {
        XCTAssertTrue(v1 > v2)
        XCTAssertTrue(v1 >= v2)
        XCTAssertTrue(v1 != v2)
        XCTAssertFalse(v1 == v2)
        XCTAssertFalse(v1 <= v2)
        XCTAssertFalse(v1 < v2)
    }

}
