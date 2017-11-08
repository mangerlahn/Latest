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
        
        if c1.count > c2.count {
            for index in (0...c2.count) {
                if c1[index] > c2[index] {
                    return false
                } else if c1[index] < c2[index] {
                    return true
                }
            }
            
            return true
        } else {
            for index in (0...c1.count - 1) {
                if c1[index] > c2[index] {
                    return false
                } else if c1[index] < c2[index] {
                    return true
                }
            }
            
            return true
        }
    }
    
    static func >=(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        let v1 = lhs.versionNumber ?? lhs.buildNumber
        let v2 = rhs.versionNumber ?? rhs.buildNumber
        
        guard let c1 = v1?.versionComponents(), let c2 = v2?.versionComponents() else {
            return false
        }
        
        if c1.count > c2.count {
            for index in (0...c2.count) {
                if c1[index] > c2[index] {
                    return true
                } else if c1[index] < c2[index] {
                    return false
                }
            }
            
            return true
        } else {
            for index in (0...c1.count - 1) {
                if c1[index] > c2[index] {
                    return true
                } else if c1[index] < c2[index] {
                    return false
                }
            }
            
            return true
        }
    }
    
    static func <(lhs: MLMVersion, rhs: MLMVersion) -> Bool {
        return lhs < rhs && lhs != rhs
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
