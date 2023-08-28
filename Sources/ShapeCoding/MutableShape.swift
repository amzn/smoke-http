// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  MutableShape.swift
//  ShapeCoding
//

import Foundation

/// An enumeration of possible types of a shape that can be muted.
public enum MutableShape {
    case dictionary(MutableShapeDictionary)
    case string(String)
    case null
    
    /**
     Finalizes this MutableShape as a Shape.
     */
    public func asShape() -> Shape {
        switch self {
        case .dictionary(let innerDictionary):
            return innerDictionary.asShape()
        case .string(let value):
            return .string(value)
        case .null:
            return .null
        }
    }
}

/// An enumeration of possible types of a shape.
public enum Shape: Equatable {
    case dictionary([String: Shape])
    case string(String)
    case null
}

/// An enumeration of possible types of MutableShapes that can have nested shapes.
public enum NestableMutableShape {
    case dictionary(MutableShapeDictionary)
    
    /**
     Finalizes this MutableShape as a Shape.
     */
    public func asShape() -> Shape {
        switch self {
        case .dictionary(let innerDictionary):
            return innerDictionary.asShape()
        }
    }
}

/// A MutableShape type for a dictionary of MutableShapes
public class MutableShapeDictionary {
    private var values: [String: MutableShape] = [:]
    
    /**
     Initializer with an empty dictionary.
     */
    public init() {
        
    }
    
    /**
     Get a value from the current state of the dictionary.
 
     - Parameters:
        - key: the key of the value to retrieve
        - Returns: the value of the provided key or nil if there is no such value
     */
    public subscript(key: String) -> MutableShape? {
        get {
            return values[key]
        }
        set(newValue) {
            values[key] = newValue
        }
    }
    
    /**
     Finalizes this MutableShapeDictionary as a Shape.
     */
    public func asShape() -> Shape {
        let transformedValues: [String: Shape] = values.mapValues { value in
            return value.asShape()
        }
        
        return .dictionary(transformedValues)
    }
}
