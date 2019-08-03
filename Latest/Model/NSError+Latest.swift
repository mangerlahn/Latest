//
//  NSError+Latest.swift
//  Latest
//
//  Created by Max Langer on 27.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Foundation

extension NSError {
	
	struct LatestErrorCodes {
	}
	
	private static let domain = "com.max-langer.latest"

	convenience init(latestErrorWithCode code: Int, localizedDescription: String) {
		self.init(domain: Self.domain, code: 1, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
	}
	
}
