//
//  SparkleFeedURLTest.swift
//  Latest Tests
//
//  Created for regression coverage.
//

import XCTest
@testable import Latest

final class SparkleFeedURLTest: XCTestCase {
	
	func testWiresharkFeedURLUsesArmArchitecture() {
		let originalURL = URL(string: "https://www.wireshark.org/update/0/Wireshark/4.4.5/macOS/x86-64/en-US/stable.xml")!
		let adjustedURL = Sparke.adjustedFeedURL(
			originalURL,
			bundleIdentifier: "org.wireshark.Wireshark",
			executableArchitectures: [NSNumber(value: NSBundleExecutableArchitectureARM64)]
		)
		
		XCTAssertEqual(adjustedURL.absoluteString, "https://www.wireshark.org/update/0/Wireshark/4.4.5/macOS/arm64/en-US/stable.xml")
	}
	
	func testWiresharkFeedURLKeepsIntelArchitecture() {
		let originalURL = URL(string: "https://www.wireshark.org/update/0/Wireshark/4.4.5/macOS/x86-64/en-US/stable.xml")!
		let adjustedURL = Sparke.adjustedFeedURL(
			originalURL,
			bundleIdentifier: "org.wireshark.Wireshark",
			executableArchitectures: [NSNumber(value: NSBundleExecutableArchitectureX86_64)]
		)
		
		XCTAssertEqual(adjustedURL, originalURL)
	}
	
	func testNonWiresharkFeedURLIsUnchanged() {
		let originalURL = URL(string: "https://example.com/appcast.xml")!
		let adjustedURL = Sparke.adjustedFeedURL(
			originalURL,
			bundleIdentifier: "com.example.App",
			executableArchitectures: [NSNumber(value: NSBundleExecutableArchitectureARM64)]
		)
		
		XCTAssertEqual(adjustedURL, originalURL)
	}
	
}
