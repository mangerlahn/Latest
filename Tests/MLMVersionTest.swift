//
//  MLMVersionTest.swift
//  Latest Tests
//
//  Created by Max Langer on 14.11.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import XCTest
@testable import Latest

class MLMVersionTest: XCTestCase {

    func testInitialization() {
        // Simple test
        var version = MLMVersion("2.1.5", "215")
        
        XCTAssertEqual(version.versionNumber, "2.1.5")
        XCTAssertEqual(version.buildNumber, "215")
        
        // Nil test
        version = MLMVersion(nil, nil)
        XCTAssertNil(version.versionNumber)
        XCTAssertNil(version.buildNumber)
    }
    
    
    // MARK: - Right Comparison
    
    func testRightComparison() {
        // If bundle is available, check for the bundle
        
        // Should check the bundle version
        var v1 = MLMVersion("2.1.5", "312")
        var v2 = MLMVersion("2.1.6d12", "215")
        self.newer(v1, v2)
        
        // Should check the version
        v1 = MLMVersion("2.1.5", nil)
        v2 = MLMVersion("2.2.6", "216")
        self.older(v1, v2)
        
        // Should check the version
        v1 = MLMVersion("2.1.5", "215")
        v2 = MLMVersion("2.2.6", nil)
        self.older(v1, v2)
        
        // Should check the version
        v1 = MLMVersion("2.1.5", nil)
        v2 = MLMVersion("2.2.6", nil)
        self.older(v1, v2)
    }
    
    
    // MARK: - Bundle Checking
    
    func testOlderBundle() {
        var v1 = MLMVersion("2.1.5", "215")
        var v2 = MLMVersion("2.1.6", "216")
        self.older(v1, v2)
        
        v1 = MLMVersion("2.1.5", "215a")
        v2 = MLMVersion("2.2.6", "216b")
        self.older(v1, v2)
    }
    
    func testEqualBundle() {
        let v1 = MLMVersion("2.1.5", "215")
        let v2 = MLMVersion("2.1.5", "215")
        self.equal(v1, v2)
    }
    
    func testNewerBundle() {
        var v1 = MLMVersion("2.0.6", "217")
        var v2 = MLMVersion("2.1.5", "216")
        self.newer(v1, v2)
        
        v1 = MLMVersion("2.1.6", "217a")
        v2 = MLMVersion("2.2.4", "216b")
        self.newer(v1, v2)
    }
    
    // MARK: - Version Checking
    
    func testOlderVersionSimple() {
        var v1 = MLMVersion("2.1.5", nil)
        var v2 = MLMVersion("2.1.6", "216")
        self.older(v1, v2)
        
        v1 = MLMVersion("2.1.5", "215")
        v2 = MLMVersion("2.2.6", nil)
        self.older(v1, v2)
        
        v1 = MLMVersion("2.1.5", nil)
        v2 = MLMVersion("3.1.6", nil)
        self.older(v1, v2)
    }

    func testEqualVersionSimple() {
        var v1 = MLMVersion("2.1.5", nil)
        var v2 = MLMVersion("2.1.5", "215")
        self.equal(v1, v2)

        v1 = MLMVersion("2.2.6", "215")
        v2 = MLMVersion("2.2.6", nil)
        self.equal(v1, v2)

        v1 = MLMVersion("3.1.6", nil)
        v2 = MLMVersion("3.1.6", nil)
        self.equal(v1, v2)
    }

    func testNewerVersionSimple() {
        var v1 = MLMVersion("2.1.6", nil)
        var v2 = MLMVersion("2.1.5", "216")
        self.newer(v1, v2)


        v1 = MLMVersion("2.3.6", "215")
        v2 = MLMVersion("2.2.4", nil)
        self.newer(v1, v2)

        v1 = MLMVersion("4.1.5", nil)
        v2 = MLMVersion("3.1.6", nil)
        self.newer(v1, v2)
    }
    
    func testOlderVersion() {
        let v1 = MLMVersion("2.1.5", nil)
        let v2 = MLMVersion("v2.1.6", "216")
        self.older(v1, v2)
    }
    
    func testEqualVersion() {
        var v1 = MLMVersion("2.1.5", nil)
        var v2 = MLMVersion("2.1.5.0", "215")
        self.equal(v1, v2)
        
        v1 = MLMVersion("2.2.6.0", "215")
        v2 = MLMVersion("2.2.6", nil)
        self.equal(v1, v2)
        
        v1 = MLMVersion("v2.2.6", nil)
        v2 = MLMVersion("2.2.6", nil)
        self.equal(v1, v2)
    }
    
    func testNewerVersion() {
        var v1 = MLMVersion("v3.1.5", nil)
        var v2 = MLMVersion("2.1.6", "216")
        self.newer(v1, v2)
        
        v1 = MLMVersion("3.1.5", "215")
        v2 = MLMVersion("v2.2.6", nil)
        self.newer(v1, v2)
    }
    
    // MARK: - Helper Methods
    
    private func older(_ v1: MLMVersion, _ v2: MLMVersion) {
        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v1 <= v2)
        XCTAssertTrue(v1 != v2)
        XCTAssertFalse(v1 == v2)
        XCTAssertFalse(v1 >= v2)
        XCTAssertFalse(v1 > v2)
    }
    
    private func equal(_ v1: MLMVersion, _ v2: MLMVersion) {
        XCTAssertTrue(v1 >= v2)
        XCTAssertTrue(v1 <= v2)
        XCTAssertTrue(v1 == v2)
        XCTAssertFalse(v1 != v2)
        XCTAssertFalse(v1 < v2)
        XCTAssertFalse(v1 > v2)
    }
    
    private func newer(_ v1: MLMVersion, _ v2: MLMVersion) {
        XCTAssertTrue(v1 > v2)
        XCTAssertTrue(v1 >= v2)
        XCTAssertTrue(v1 != v2)
        XCTAssertFalse(v1 == v2)
        XCTAssertFalse(v1 <= v2)
        XCTAssertFalse(v1 < v2)
    }

}
