//
//  FailableDecodable.swift
//  Latest
//
//  Created by Max Langer on 07.10.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

/// A wrapper for optionally decoding a given object.
///
/// Ensures that the overall decoding succeeds even if individual items may fail to decode.
/// Based on: https://stackoverflow.com/a/46369152/4113940
struct FailableDecodable<Content : Decodable> : Decodable {
	
	let base: Content?
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.base = try? container.decode(Content.self)
	}
	
}
