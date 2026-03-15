//
//  MacAppStoreCheckerOperationTest.swift
//  Latest Tests
//
//  Created by Codex on 16.03.26.
//

import XCTest
@testable import Latest

final class MacAppStoreCheckerOperationTest: XCTestCase {

	func testStorefrontLanguageIdentifierUsesEnglishOverride() {
		let identifier = MacAppStoreUpdateCheckerOperation.storefrontLanguageIdentifier(preferredLanguages: ["en-HK"])
		XCTAssertEqual(identifier, "en_us")
	}

	func testStorefrontLanguageIdentifierUsesJapaneseOverride() {
		let identifier = MacAppStoreUpdateCheckerOperation.storefrontLanguageIdentifier(preferredLanguages: ["ja-JP"])
		XCTAssertEqual(identifier, "ja_jp")
	}

	func testStorefrontLanguageIdentifierSkipsUnsupportedLanguages() {
		let identifier = MacAppStoreUpdateCheckerOperation.storefrontLanguageIdentifier(preferredLanguages: ["zh-Hant-HK"])
		XCTAssertNil(identifier)
	}

	func testStorefrontLanguageIdentifierHandlesMissingPreference() {
		let identifier = MacAppStoreUpdateCheckerOperation.storefrontLanguageIdentifier(preferredLanguages: [])
		XCTAssertNil(identifier)
	}

}
