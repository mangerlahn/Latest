//
//  main.swift
//  UpdateInstaller
//
//  Created by Max Langer on 06.01.26.
//  Copyright © 2026 Max Langer. All rights reserved.
//

import Foundation
import os

/// Code signing requirement for the main app: only Latest may connect to this daemon.
private let appCodeSigningRequirement = "identifier \"com.max-langer.Latest\" and certificate leaf[subject.OU] = \"VFABJ5RE5Q\""

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
	/// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.setCodeSigningRequirement(appCodeSigningRequirement)
		newConnection.exportedInterface = NSXPCInterface(with: UpdateInstallerProtocol.self)

		let exportedObject = UpdateInstaller()
		newConnection.exportedObject = exportedObject
		newConnection.resume()
		
		return true
	}
}

// Create the delegate for the service.
let delegate = ServiceDelegate()

// Create and start the listener
let listener = NSXPCListener(machServiceName: "com.max-langer.latest.UpdateInstaller")
listener.delegate = delegate
listener.resume()

// Keep the main run loop running
RunLoop.current.run()

