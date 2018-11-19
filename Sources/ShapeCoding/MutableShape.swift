// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

/// An enumeration of possible types of MutableShapes.
public enum MutableShape {
    case dictionary(MutableShapeDictionary)
    
    /**
     Finalizes this MutableShapeAttribute as a ShapeAttribute.
     */
    public func asShapeAttribute() -> ShapeAttribute {
        switch self {
        case .dictionary(let innerDictionary):
            return innerDictionary.asShapeAttribute()
        }
    }
}

/// A MutableShape type for a dictionary of MutableShapeAttributes
public class MutableShapeDictionary {
    private var values: [String: MutableShapeAttribute] = [:]
    
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
    public subscript(key: String) -> MutableShapeAttribute? {
        get {
            return values[key]
        }
        set(newValue) {
            values[key] = newValue
        }
    }
    
    /**
     Finalizes this MutableShapeDictionary as a ShapeAttribute.
     */
    public func asShapeAttribute() -> ShapeAttribute {
        let transformedValues: [String: ShapeAttribute] = values.mapValues { value in
            return value.asShapeAttribute()
        }
        
        return .dictionary(transformedValues)
    }
}

/// An enumeration of possible values of a shape that can be mutated.
public enum MutableShapeAttribute {
    case dictionary(MutableShapeDictionary)
    case string(String)
    case null
    
    /**
     Finalizes this MutableShapeAttribute as a ShapeAttribute.
     */
    public func asShapeAttribute() -> ShapeAttribute {
        switch self {
        case .dictionary(let innerDictionary):
            return innerDictionary.asShapeAttribute()
        case .string(let value):
            return .string(value)
        case .null:
            return .null
        }
    }
}

/// An enumeration of the possible types of attributes for a shape
public enum ShapeAttribute: Equatable {
    case dictionary([String: ShapeAttribute])
    case string(String)
    case null
}
