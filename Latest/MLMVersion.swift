//
//  Version.swift
//  Latest
//
//  Created by Max Langer on 01.11.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

struct MLMVersion : Equatable, Comparable {
    
    var versionNumber : String?
    var buildNumber : String?
    
    init(_ version: String? = nil, _ buildNumber: String? = nil) {
        self.versionNumber = version
        self.buildNumber = buildNumber
    }
    
    static func ==(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        return (lhs >= rhs) && (lhs <= rhs)
    }
    
    static func !=(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        return !(lhs == rhs)
    }
    
    static func <=(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        let v1 = lhs.versionNumber ?? lhs.buildNumber
        let v2 = rhs.versionNumber ?? rhs.buildNumber
        
        guard let c1 = v1?.versionComponents(), let c2 = v2?.versionComponents() else {
            return false
        }
        
        let result = self._check(lhs: c1, rhs: c2)
        return result == .equal || result == .older
    }
    
    static func >=(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        let v1 = lhs.versionNumber ?? lhs.buildNumber
        let v2 = rhs.versionNumber ?? rhs.buildNumber
        
        guard let c1 = v1?.versionComponents(), let c2 = v2?.versionComponents() else {
            return false
        }
        
        let result = self._check(lhs: c1, rhs: c2)
        return result == .equal || result == .newer
    }
    
    static func <(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        return lhs < rhs && lhs != rhs
    }
    
    
    // MARK: - Private
    
    private enum CheckingResult {
        case older, newer, equal
    }
    
    private static func _check(lhs: [Int], rhs: [Int]) -> CheckingResult {
        let upperBounds = lhs.count > rhs.count ? rhs.count : lhs.count
        
        for index in (0..<upperBounds) {
            if lhs[index] > rhs[index] {
                return .newer
            } else if lhs[index] < rhs[index] {
                return .older
            }
        }
        
        return lhs.count > rhs.count ? .older : .equal
    }
}

extension String {
    func versionComponents() -> [Int] {
        let components = self.components(separatedBy: ".")
        var versionComponents = [Int]()
        
        components.forEach { (component) in
            if let number = Int.init(component) {
                versionComponents.append(number)
            }
        }
        
        return versionComponents
    }
}
