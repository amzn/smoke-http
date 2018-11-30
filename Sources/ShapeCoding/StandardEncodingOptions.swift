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
//  StandardEncodingOptions.swift
//  ShapeCoding
//

import Foundation

/// The strategy to use for encoding shape keys.
public enum ShapeKeyEncodingStrategy {
    /// The encoder will concatinate attribute keys specified character to indicate a
    /// nested structure that could include nested types, dictionaries and arrays. This is the default.
    ///
    /// Array entries are indicated by a 1-based index
    /// ie. ShapeOutput(theArray: ["Value1", "Value2"]) --> ["theArray.1": "Value1", "theArray.2": "Value2]
    /// Nested type attributes are indicated by the attribute keys
    /// ie. ShapeOutput(theType: TheType(foo: "Value1", bar: "Value2")) ?theType.foo=Value1&theType.bar=Value2
    /// Dictionary entries are indicated based on the provided `ShapeMapEncodingStrategy`
    case useAsShapeSeparator(Character)
    
    /// The encoder will concatinate attribute keys with no separator.
    case noSeparator
    
    /// Get the separator string to use for this strategy
    var separatorString: String {
        switch self {
        case .useAsShapeSeparator(let character):
            return "\(character)"
        case .noSeparator:
            return ""
        }
    }
}

/// The strategy to use for encoding maps.
public enum ShapeMapEncodingStrategy {
    /// The output will contain a single shape entry for
    /// each entry of the map. This is the default.
    /// ie. ShapeOutput(theMap: ["Key": "Value"]) --> ["theMap.Key": "Value"]
    case singleShapeEntry

    /// The output will contain separate entries for the key and value
    /// of each entry of the map, specified as a list.
    /// ie. ShapeOutput(theMap: ["Key": "Value"]) --> ["theMap.1.KeyTag": "Key", "theMap.1.ValueTag": "Value"]
    case separateShapeEntriesWith(keyTag: String, valueTag: String)
}

/// The standard encoding options to use in conjunction with
/// StandardShapeSingleValueEncodingContainerDelegate.
public struct StandardEncodingOptions {
    public let shapeKeyEncodingStrategy: ShapeKeyEncodingStrategy
    public let shapeMapEncodingStrategy: ShapeMapEncodingStrategy
    
    public init(shapeKeyEncodingStrategy: ShapeKeyEncodingStrategy,
                shapeMapEncodingStrategy: ShapeMapEncodingStrategy) {
        self.shapeKeyEncodingStrategy = shapeKeyEncodingStrategy
        self.shapeMapEncodingStrategy = shapeMapEncodingStrategy
    }
}
