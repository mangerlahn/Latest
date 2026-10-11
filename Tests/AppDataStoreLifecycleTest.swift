//
//  AppDataStoreLifecycleTest.swift
//  LatestTests
//

import XCTest
@testable import Latest

final class AppDataStoreLifecycleTest: XCTestCase {
	
	/// The store schedules its observer notifications on a background queue. That notification can run after the store has been released and must not crash.
	func testReleasingAStoreWithAPendingNotificationDoesNotCrash() {
		for _ in 0..<100 {
			autoreleasepool {
				let bundle = App.Bundle(version: Version(versionNumber: "1.0", buildNumber: nil), name: "Sample", bundleIdentifier: "test.sample.\(UUID().uuidString)", fileURL: URL(fileURLWithPath: "/Applications/Sample.app"), source: .none)
				let store = AppDataStore()
				_ = store.set(appBundles: [bundle])
			}
		}
		
		// Give the pending notifications time to run after the stores are gone.
		let drained = expectation(description: "Pending notifications ran")
		DispatchQueue.global().asyncAfter(deadline: .now() + 2) { drained.fulfill() }
		wait(for: [drained], timeout: 10)
	}
	
}
