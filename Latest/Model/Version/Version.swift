//
//  Version.swift
//  Latest
//
//  Created by Max Langer on 01.11.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

/**
 A Version represents a single version of an app. It contains both the version number and the build number to uniquely
 identify an app (in theory).
 Comparisons of versions results in an actual comparison. I.E. 1.4.2 > 1.3.5
 Also, if the two versions are the same, or the strings are not parsable, the build numbers get compared.
 This class is very much work in progress and needs some deep thoughts on edge cases and a more clever implementation
 */
struct Version : Hashable, Comparable {
	
	/// The version number itself
	let versionNumber : String?
	
	/// The build number itself
	let buildNumber : String?
	
	/// Flag whether both version number and build number are unavailable
	var isEmpty: Bool {
		let versionNumberComponents = versionNumber?.components().compactMap({ $0.plainComponent }).joined()
		let buildNumberComponents = buildNumber?.components().compactMap({ $0.plainComponent }).joined()
		
		return (versionNumberComponents?.isEmpty ?? true && buildNumberComponents?.isEmpty ?? true)
	}
	
	
	// MARK: - Comparisons
	
	static func ==(lhs: Version, rhs: Version) -> Bool {
		compare(lhs, rhs) == .equal
	}
	
	static func <(lhs: Version, rhs: Version) -> Bool {
		compare(lhs, rhs) == .older
	}
	
	static func >(lhs: Version, rhs: Version) -> Bool {
		compare(lhs, rhs) == .newer
	}
	
	
	// MARK: - Hashing
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(versionNumber)
		hasher.combine(buildNumber)
	}
	
	
	// MARK: - Private
	
	/// An enum describing the result of an comparison.
	private enum CheckingResult {
		case older, newer, equal, undefined
	}
	
	/// Performs the actual check. This version checker is adopted by the Sparkle Framework and slightly adapted.
	private static func compare(_ lhs: Version, _ rhs: Version) -> CheckingResult {
		var v1 : String?
		var v2 : String?
		
		// Only allow build number checks if build- and version number actually differ
		let allowBuildNumberCheck = lhs.buildNumber != lhs.versionNumber
		if allowBuildNumberCheck, let b1 = lhs.buildNumber, let b2 = rhs.buildNumber {
			v1 = b1
			v2 = b2
		} else {
			v1 = lhs.versionNumber
			v2 = rhs.versionNumber
		}
		
		guard let c1 = v1?.components(), let c2 = v2?.components() else {
			return .undefined
		}
		
		let count1 = c1.count
		let count2 = c2.count
		for i in 0..<min(count1, count2) {
			guard case .component(let component1) = c1[i], case .component(let component2) = c2[i] else { continue }
			
			let atomsCount1 = component1.count
			let atomsCount2 = component2.count
			for i in 0..<min(atomsCount1, atomsCount2) {
				let component1 = component1[i]
				let component2 = component2[i]
				
				// Compare numbers
				if case .number(let value1) = component1, case .number(let value2) = component2 {
					if value1 > value2 {
						return .newer // Think "1.3" vs "1.2"
					} else if value2 > value1 {
						return .older // Think "1.2" vs "1.3"
					}
				}
				
				// Compare letters
				else if case .string(let value1) = component1, case .string(let value2) = component2 {
					switch value1.compare(value2) {
					case .orderedAscending:
						return .older // Think "1.2A" vs "1.2B"
					case .orderedDescending:
						return .newer // Think "1.2B" vs "1.2A"
					default: ()
					}
				}
				
				
				// Not the same type? Now we have to do some validity checking
				else if case .string(_) = component1 {
					return .older // Think "1.2A" vs "1.2.2"
				}
				
				else if case .string(_) = component2 {
					return .newer // Think "1.2.3" vs "1.2A"
				}
				
				
				// One is a number and the other is a period. The period is invalid
				else if case .number(_) = component1 {
					return .older // Think "1.2.." vs "1.2.0"
				}
				
				else if case .number(_) = component2 {
					return .newer // Think "1.2.3" vs "1.2.."
				}
			}
		}
		
		// The versions are equal up to the point where they both still have parts
		// Lets check to see if one is larger than the other
		if count1 != count2 {
			let l = count1 > count2
			let longerComponents = (l ? c1 : c2)[(l ? count2 : count1)...]
			guard case .component(let atoms) = longerComponents.first(where: { if case .component(_) = $0 { true } else { false } }) else {
				return .equal // Think "1.2" vs "1.2."
			}
			
			if case .number(let number) = atoms.first {
				if number == 0 {
					return .equal // Think "1.2" vs "1.2.0"
				}
				
				return l ? .newer : .older // Think "1.2" vs "1.2.2"
			}
			
			return l ? .older : .newer // Think "1.2" vs "1.2A"
		}
		
		return .equal // Think "1.2" vs "1.2"
	}
}

extension Version: CustomDebugStringConvertible {
	var debugDescription: String {
		return "Version: \(versionNumber ?? "None"), Build: \(buildNumber ?? "None")"
	}
}

/// An extension helping the version checking
fileprivate extension String {
	
	/**
	 Returns the components of an version number.
	 Components are grouped by Character type, so "12.3" returns [("12", .number), (".", .separator), ("3", .number)]
	 */
	func components() -> [Version.Segment] {
		let scanner = Scanner(string: self)
		
		var components = [Version.Segment]()
		var currentAtoms = [Version.Segment.Atom]()
		
		while !scanner.isAtEnd {
			var number: Int = 0
			
			// Try to scan number
			if scanner.scanInt(&number) {
				currentAtoms.append(.number(value: number))
			}
			
			// Try to scan separator
			else if let string = scanner.scanCharacters(from: .separators) {
				components.append(.component(atoms: currentAtoms))
				components.append(.separator(character: string as String))
				
				currentAtoms.removeAll()
			}
			
			// Try to scan anything else
			else if let string = scanner.scanCharacters(from: .letters) {
				currentAtoms.append(.string(value: string as String))
			}
			
			else {
				fatalError("Unable to parse version string: \(self)")
			}
		}
		
		if !currentAtoms.isEmpty {
			components.append(.component(atoms: currentAtoms))
		}
		
		return components
	}
}

fileprivate extension CharacterSet {
	
	/// Contains all delimiters used by a version string
	static let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
	
	/// Contains any characters but separators and digits
	static let letters = CharacterSet.separators.union(.decimalDigits).inverted
	
}

// Defining the type of a character
fileprivate extension Version {
	enum Segment: Equatable {
		
		enum Atom: Equatable {
			case number(value: Int) // 0..9
			case string(value: String) // Everything else
			
			func isSameType(_ other: Atom) -> Bool {
				switch (self, other) {
				case (.number(_), .number(_)),
					(.string(_), .string(_)):
					return true
				default:
					return false
				}
			}
		}
		
		case separator(character: String) // Newlines, punctuation..
		case component(atoms: [Atom]) // [123, A]
		
		var plainComponent: String? {
			guard case .component(let atoms) = self else {
				return nil
			}
			
			return atoms.map { atom in
				switch atom {
				case .number(let value):
					return "\(value)"
				case .string(let value):
					return value
				}
			}.joined()
		}
		
		func isSameType(_ other: Segment) -> Bool {
			switch (self, other) {
			case (.separator, .separator),
				(.component(_), .component(_)):
				return true
			default:
				return false
			}
		}
		
	}
	
}

extension Array where Element == Version.Segment {
	func joined() -> String? {
		let string = self.map { segment in
			switch segment {
			case .separator(let character):
				character
			case .component(_):
				segment.plainComponent!
			}
		}.joined()
		
		return string.isEmpty ? nil : string
	}
}


// MARK: - Version Sanitization

extension Version {
	
	func sanitize(with appVersion: Version) -> Version {
		// The last component of the version number is actually the build number. (Can only be detected for equal build numbers. Avoids false positives)
		// App: 1.2 (40)
		// Remote: 1.2.40
		if buildNumber == nil, var components = versionNumber?.components(), let lastRemoteComponent = components.last?.plainComponent, lastRemoteComponent == appVersion.buildNumber {
			// Remove build number segment from version number and store it separately.
			let buildNumber = components.removeLast()
			
			// Remove separator as well.
			if !components.isEmpty {
				components.removeLast()
			}
			
			return Version(versionNumber: components.joined(), buildNumber: buildNumber.plainComponent)
		}
		
		// The entire version number equals the app versions build number. We assume version number by default, but that may not be the case.
		if let versionNumber, versionNumber == appVersion.buildNumber {
			// Switch to build number.
			return Version(versionNumber: nil, buildNumber: versionNumber)
		}

		//
		if appVersion.buildNumber == appVersion.versionNumber, var components = versionNumber?.components(), components.last?.plainComponent != nil, components.count == 7 {
			components.removeLast()
			components.removeLast()
			
			if components.joined() == appVersion.buildNumber {
				return Version(versionNumber: components.joined(), buildNumber: buildNumber)
			}
		}
		
		// Nothing changed
		return self
	}
	
}


// MARK: -

extension OperatingSystemVersion {
	
	init(string: String) throws {
		let components = string.components().flatMap({ component in
			switch component {
			case .component(let atoms):
				return atoms.compactMap { atom in
					switch atom {
					case .number(let value):
						return value
					default:
						return nil
					}
				}
			default:
				return []
			}
		})
		guard !components.isEmpty else { throw OperatingSystemVersionError.parsingError(version: string) }
		
		let major = components[0]
		let minor = components.count > 1 ? components[1] : 0
		let patch = components.count > 2 ? components[2] : 0
		self.init(majorVersion: major, minorVersion: minor, patchVersion: patch)
	}
	
	enum OperatingSystemVersionError: Error {
		case parsingError(version: String)
	}
	
}

