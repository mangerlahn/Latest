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
        let result = self._check(lhs, rhs)
        return result == .equal
    }
    
    static func !=(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        return !(lhs == rhs)
    }
    
    static func <=(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .equal || result == .older
    }
    
    static func >=(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .equal || result == .newer
    }
    
    static func <(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        let result = self._check(lhs, rhs)
        return result == .older
    }
    
    
    // MARK: - Private
    
    private enum CheckingResult {
        case older, newer, equal, undefined
    }
    
    private static func _check(_ lhs: MLMVersion, _ rhs: MLMVersion) -> CheckingResult {
        let v1 = lhs.versionNumber ?? lhs.buildNumber
        let v2 = rhs.versionNumber ?? rhs.buildNumber
        
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
