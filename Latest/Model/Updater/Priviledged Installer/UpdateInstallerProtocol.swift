//
//  InstallerProtocol.swift
//  Installer
//
//  Created by Max Langer on 06.01.26.
//  Copyright © 2026 Max Langer. All rights reserved.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol UpdateInstallerProtocol {
    /// Replace the API of this protocol with an API appropriate to the service you are vending.
	func performInstallation(ofPackageAt url: URL, targetURL: String, receiptData: Data, receiptURL: URL, reply: @escaping (Error?) -> Void)
}
