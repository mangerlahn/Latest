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
        return self.versionNumber == nil && self.buildNumber == nil
    }
    
    
    // MARK: - Comparisons
    
    static func ==(lhs: Version, rhs: Version) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .equal
    }
    
    static func <(lhs: Version, rhs: Version) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .older
    }
    
    static func >(lhs: Version, rhs: Version) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .newer
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
    private static func _check(_ lhs: Version, _ rhs: Version) -> CheckingResult {
        var v1 : String?
        var v2 : String?
        
        if let b1 = lhs.buildNumber, let b2 = rhs.buildNumber {
            v1 = b1
            v2 = b2
        } else {
            v1 = lhs.versionNumber
            v2 = rhs.versionNumber
        }
        
        guard var c1 = v1?.versionComponents(), var c2 = v2?.versionComponents() else {
            return .undefined
        }
        
        c1.cutVersionPrefix()
        c2.cutVersionPrefix()
        
        let count1 = c1.count
        let count2 = c2.count
        for i in 0..<min(count1, count2) {
            let component1 = c1[i]
            let component2 = c2[i]
            
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
        
        // The versions are equal up to the point where they both still have parts
        // Lets check to see if one is larger than the other
        if count1 != count2 {
            let l = count1 > count2
            let longerComponents = (l ? c1 : c2)[(l ? count2 : count1)...]
            guard let component = longerComponents.first(where: { $0 != .separator }) else {
                return .equal // Think "1.2" vs "1.2."
            }
            
			if case .number(let number) = component {
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
    func versionComponents() -> [VersionComponent] {
		let scanner = Scanner(string: self)

		var components = [VersionComponent]()
		while !scanner.isAtEnd {
			var number: Int = 0
			var string: NSString? = ""
			
			// Try to scan number
			if scanner.scanInt(&number) {
				components.append(.number(value: number))
			}
			
			// Try to scan separator
			else if scanner.scanCharacters(from: .separators, into: nil) {
				components.append(.separator)
			}
			
			// Try to scan anything else
			else if scanner.scanCharacters(from: .letters, into: &string), let string {
				components.append(.string(value: string as String))
			}
			
			else {
				fatalError("Unable to parse version string: \(self)")
			}
		}

		return components
    }
}

fileprivate extension Array where Element == VersionComponent {

    /// Removes any leading v of a version number ("v1.2" -> "1.2")
    mutating func cutVersionPrefix() {
		guard let component = self.first, case .string(let value) = component, value == "v" else { return }
		self.removeFirst()
    }
    
}

fileprivate extension CharacterSet {
	
	/// Contains all delimiters used by a version string
	static let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
	
	/// Contains any characters but separators and digits
	static let letters = CharacterSet.separators.union(.decimalDigits).inverted
	
}

// Defining the type of a character
fileprivate enum VersionComponent: Equatable {

    case separator // Newlines, punctuation..
	case number(value: Int) // 0..9
	case string(value: String) // Everything else
	
	func isSameType(_ other: VersionComponent) -> Bool {
		switch (self, other) {
			case (.separator, .separator),
				(.number(_), .number(_)),
				(.string(_), .string(_)):
				return true
			default:
				return false
		}
	}
	
}


// MARK: -

extension OperatingSystemVersion {
	
	init(string: String) throws {
		let components = string.versionComponents().compactMap({ component in
			switch component {
				case .number(let value):
					return value
				default:
					return nil
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

