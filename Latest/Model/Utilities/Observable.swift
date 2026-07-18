//
//  Observable.swift
//  Latest
//
//  Created by Max Langer on 20.01.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

import Foundation

/// A uniquely identifiable observer.
protocol Observer: Identifiable where ID == UUID {}

/// An observable object.
protocol Observable {
	
	/// The handler called when an observation is notified.
	typealias ObservationHandler = () -> Void
	
	/// The list of observers.
	var observers: [UUID: ObservationHandler] { get set }

	/// Adds the observer with the given handler to the list of observers.
	mutating func add(_ observer: any Observer, handler: @escaping ObservationHandler)
	
	/// Removes the given observer from the list.
	mutating func remove(_ observer: any Observer)
	
	/// Notifies the observers of an observation.
	func notify()
		
}

extension Observable {
	
	mutating func add(_ observer: any Observer, handler: @escaping ObservationHandler) {
		observers[observer.id] = handler
	}
	
	mutating func remove(_ observer: any Observer) {
		observers.removeValue(forKey: observer.id)
	}
	
	func notify() {
		observers.forEach({ $1() })
	}
	
}

/// Shared diagnostics logger for opt-in runtime tracing.
enum DiagnosticsLog {
	enum Category: String {
		case appDirectory = "AppDirectory"
		case updateCheckCoordinator = "UpdateCheckCoordinator"
		case mainWindow = "MainWindowController"
	}

	static let userDefaultsKey = "diagnosticsTracingEnabled"
	private static let environmentKey = "LATEST_ENABLE_DIAGNOSTICS_TRACE"
	private static let fileName = "Diagnostics.log"

	static var isEnabled: Bool {
		UserDefaults.standard.bool(forKey: userDefaultsKey) || ProcessInfo.processInfo.environment[environmentKey] == "1"
	}

	static var logFileURL: URL {
		let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
		return baseURL.appendingPathComponent(fileName)
	}

	static func trace(_ category: Category, _ message: @autoclosure () -> String) {
		guard isEnabled else { return }

		let line = "[\(category.rawValue)] \(message())\n"
		guard let data = line.data(using: .utf8) else { return }

		let url = logFileURL
		if FileManager.default.fileExists(atPath: url.path) {
			if let handle = try? FileHandle(forWritingTo: url) {
				handle.seekToEndOfFile()
				handle.write(data)
				handle.closeFile()
			}
		} else {
			try? data.write(to: url)
		}
	}
}
