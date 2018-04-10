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
    
    static func !=(lhs: Version, rhs: Version) -> Bool {
        return !(lhs == rhs)
    }
    
    static func <=(lhs: Version, rhs: Version) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .equal || result == .older
    }
    
    static func >=(lhs: Version, rhs: Version) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .equal || result == .newer
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
    
    /**
     Performs the actual check. Currently, the build number is preferred for checking, as it is mostly easier to parse
     Therefore the results are more accurate
     */
    private static func _check(_ lhs: Version, _ rhs: Version) -> CheckingResult {
        var v1 : String?
        var v2 : String?
        
        if let b1 = lhs.buildNumber, let b2 = rhs.buildNumber {
            return self._checkBundleVersion(b1, b2)
        } else {
            v1 = lhs.versionNumber
            v2 = rhs.versionNumber
        }
        
        guard var c1 = v1?.versionComponents(), var c2 = v2?.versionComponents() else {
            return .undefined
        }
        
        while c1.count < c2.count {
            c1.append(0)
        }
        
        while c1.count > c2.count {
            c2.append(0)
        }
        
        for index in (0..<c1.count) {
            if c1[index] > c2[index] {
                return .newer
            } else if c1[index] < c2[index] {
                return .older
            }
        }
        
        return .equal
    }
    
    /// A very dumb bundle checking function. It currently only extracts the digits of the build number and compares them
    private static func _checkBundleVersion(_ b1: String, _ b2: String) -> CheckingResult {
        let characterSet = CharacterSet.decimalDigits.inverted
        
        let d1 = String(String.UnicodeScalarView(b1.unicodeScalars.filter { !characterSet.contains($0) }))
        let d2 = String(String.UnicodeScalarView(b2.unicodeScalars.filter { !characterSet.contains($0) }))
        
        if let i1 = Int(d1), let i2 = Int(d2) {
            return i1 < i2 ? .older : i1 == i2 ? .equal : .newer
        }
 
        return .undefined
    }
}

/// An extension helping the version checking
private extension String {
    
    /**
     Returns the components of an version number.
     "1.2.5" returns [1, 2, 5] and "v2.1" returns [2, 1]
     There are still problems with other formats like "2.3.4 x86" that are currently not solved. This would return [2, 3]
     */
    func versionComponents() -> [Int] {
        let components = self.components(separatedBy: ".")
        var versionComponents = [Int]()
        
        components.forEach { (component) in
            let digits = component.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
            if let number = Int(digits) {
                versionComponents.append(number)
            }
        }
        
        return versionComponents
    }
}
