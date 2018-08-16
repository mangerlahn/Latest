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
struct Version : Equatable, Comparable {
    
    /// The version number itself
    var versionNumber : String?
    
    /// The build number itself
    var buildNumber : String?
    
    /// Flag whether both version number and build number are unavailable
    var isEmpty: Bool {
        return self.versionNumber == nil && self.buildNumber == nil
    }
    
    /**
     Convenience initializer setting both version and build number
     - parameter version: The version number
     - parameter buildNumber: The build number
     */
    init(_ version: String? = nil, _ buildNumber: String? = nil) {
        self.versionNumber = version
        self.buildNumber = buildNumber
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
            
            if component1.type == component2.type {
                if component1.type == .number {
                    let value1 = Int(component1.string)!
                    let value2 = Int(component2.string)!
                    
                    if value1 > value2 {
                        return .newer // Think "1.3" vs "1.2"
                    } else if value2 > value1 {
                        return .older // Think "1.2" vs "1.3"
                    }
                } else if component1.type == .string {
                    let result = component1.string.compare(component2.string)
                    
                    switch result {
                    case .orderedAscending:
                        return .older // Think "1.2A" vs "1.2B"
                    case .orderedDescending:
                        return .newer // Think "1.2B" vs "1.2A"
                    default: ()
                    }
                }
            } else {
                // Not the same type? Now we have to do some validity checking
                if component1.type != .string && component2.type == .string {
                    return .newer // Think "1.2.3" vs "1.2A"
                } else if component1.type == .string && component2.type != .string {
                    return .older // Think "1.2A" vs "1.2.2"
                }
                
                // One is a number and the other is a period. The period is invalid
                if component1.type == .number {
                    return .newer // Think "1.2.3" vs "1.2.."
                }
                
                return .older // Think "1.2.." vs "1.2.0"
            }
        }
        
        // The versions are equal up to the point where they both still have parts
        // Lets check to see if one is larger than the other
        if count1 != count2 {
            let l = count1 > count2
            let longerComponents = (l ? c1 : c2)[(l ? count2 : count1)...]
            guard let component = longerComponents.first(where: { $0.type != .separator }) else {
                return .equal // Think "1.2" vs "1.2."
            }
            
            if component.type == .number, let number = Int(component.string) {
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

fileprivate typealias VersionComponent = (type: CharacterType, string: String)

/// An extension helping the version checking
fileprivate extension String {
    
    /**
     Returns the components of an version number.
     Components are grouped by Character type, so "12.3" returns [("12", .number), (".", .separator), ("3", .number)]
     */
    func versionComponents() -> [VersionComponent] {
        guard let first = self.first else {
            return []
        }
        
        let components = self.dropFirst().reduce([(CharacterType.for(first)!, String(first))]) { (result: [VersionComponent], character) -> [VersionComponent] in
            var result = result
            var component = result.last!
            let newType = CharacterType.for(character)
            
            if newType != component.type || component.type == .separator {
                result.append((newType!, String(character)))
            } else {
                component.string.append(character)
                result.removeLast()
                result.append(component)
            }
            
            return result
        }
    
        return components
    }
}

fileprivate extension Array where Element == VersionComponent {

    /// Removes any leading v of a version number ("v1.2" -> "1.2")
    mutating func cutVersionPrefix() {
        guard let component = self.first else { return }
        
        if component.string == "v" {
            self.removeFirst()
        }
    }
    
}

// Defining the type of a character
fileprivate enum CharacterType {
    
    case separator // Newlines, punctuation..
    case number // 0..9
    case string // Everything else
    
    /// Returns the type for a given character
    static func `for`(_ character: Character) -> CharacterType? {
        guard let scalar = character.unicodeScalars.first else { return nil }
        
        if NSCharacterSet.decimalDigits.contains(scalar) {
            return .number
        }
        
        if NSCharacterSet.whitespacesAndNewlines.contains(scalar) || NSCharacterSet.punctuationCharacters.contains(scalar) {
            return .separator
        }
        
        return .string
    }
    
}
