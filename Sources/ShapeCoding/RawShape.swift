// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
//  RawShape.swift
//  ShapeCoding
//

import Foundation

/**
 An enumeration of possible types of a shape that retains the original decoded structure.
 Compared to the `Shape` enumeration, there a difference in how arrays are stored - `Shape`
 stores arrays as a dictionary of values keyed by a 1-based index. `RawShape` separates
 the definition of dictionaries and arrays, each in their original form.
 */
public enum RawShape: Equatable, Codable {
    case dictionary([String: RawShape])
    case array([RawShape])
    case string(String)
    
    public init(from decoder: Decoder) throws {
        do {
            let theDictionary = try [String: RawShape](from: decoder)
            
            self = .dictionary(theDictionary)
        } catch {
            do {
                let theArray = try [RawShape](from: decoder)
                
                self = .array(theArray)
            } catch {
                let theString = try String(from: decoder)
                
                self = .string(theString)
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let string):
            try string.encode(to: encoder)
        case .array(let array):
            try array.encode(to: encoder)
        case .dictionary(let map):
            try map.encode(to: encoder)
        }
    }
    
    /// Converts an instance of this enumeration to its corresponding `Shape`.
    public var asShape: Shape {
        switch self {
        case .string(let string):
            return .string(string)
        case .dictionary(let dictionary):
            let transformedDictionary = dictionary.mapValues { $0.asShape }
            
            return .dictionary(transformedDictionary)
        case .array(let array):
            var transformedDictionary: [String: Shape] = [:]
            // map each value in the array to the dictionary keyed by its 1-based index
            array.enumerated().forEach { (entry) in
                transformedDictionary["\(entry.offset + 1)"] = entry.element.asShape
            }
            
            return .dictionary(transformedDictionary)
        }
    }
}
