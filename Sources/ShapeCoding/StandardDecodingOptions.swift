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
//  StandardDecodingOptions.swift
//  ShapeCoding
//

import Foundation

/// The strategy to use for decoding shape keys.
public enum ShapeKeyDecodingStrategy {
    /// The decoder will spilt shape keys on the specified character to indicate a
    /// nested structure that could include nested types, dictionaries and arrays. This is the default.
    ///
    /// Array entries are indicated by a 1-based index
    /// ie. ["theArray.1": "Value1", "theArray.2": "Value2] --> ShapeOutput(theArray: ["Value1", "Value2"])
    /// Nested type attributes are indicated by the attribute keys
    /// ie. ["theArray.foo": "Value1", "theArray.bar": "Value2] --> ShapeOutput(theType: TheType(foo: "Value1", bar: "Value2"))
    /// Dictionary entries are indicated based on the provided `ShapeMapDecodingStrategy`
    case useAsShapeSeparator(Character)
    
    case useShapePrefix
    
    /// The decoder will decode shape keys into the attributes
    /// of the provided type. No nested types, lists or dictionaries are possible.
    case flatStructure
}

/// The strategy to use for decoding maps.
public enum ShapeMapDecodingStrategy {
    /// The decoder will expect a single shape entry for
    /// each entry of the map. This is the default.
    /// ie. ["theMap.Key": "Value"] --> ShapeOutput(theMap: ["Key": "Value"])
    case singleShapeEntry

    /// The decoder will expect separate entries for the key and value
    /// of each entry of the map, specified as a list.
    /// ie. ["theMap.1.KeyTag": "Key", "theMap.1.ValueTag": "Value"] -> ShapeOutput(theMap: ["Key": "Value"])
    case separateShapeEntriesWith(keyTag: String, valueTag: String)
}

// Structure that hold the options to use during decoding
public struct StandardDecodingOptions {
    public let shapeKeyDecodingStrategy: ShapeKeyDecodingStrategy
    public let shapeMapDecodingStrategy: ShapeMapDecodingStrategy
    
    public init(shapeKeyDecodingStrategy: ShapeKeyDecodingStrategy,
                shapeMapDecodingStrategy: ShapeMapDecodingStrategy) {
        self.shapeKeyDecodingStrategy = shapeKeyDecodingStrategy
        self.shapeMapDecodingStrategy = shapeMapDecodingStrategy
    }
}
