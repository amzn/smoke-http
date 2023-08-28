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
//  QueryEncoder.swift
//  QueryCoding
//

import Foundation
import ShapeCoding

///
/// Encode Swift types into query strings.
///
/// Nested types, arrays and dictionaries are serialized into query keys the `QueryKeyEncodingStrategy`.
/// Array entries are indicated by a 1-based index
/// ie. QueryInput(theArray: ["Value1", "Value2"]) --> ?theArray.1=Value1&theArray.2=Value2
/// Nested type attributes are indicated by the attribute keys
/// ie. QueryInput(theType: TheType(foo: "Value1", bar: "Value2")) --> ?theType.foo=Value1&theType.bar=Value2
/// Dictionary entries are indicated based on the provided `MapEncodingStrategy`
public class QueryEncoder {
    public typealias KeyEncodingStrategy = ShapeKeyEncodingStrategy
    public typealias KeyEncodeTransformStrategy = ShapeKeyEncodeTransformStrategy

    internal let options: StandardEncodingOptions
    
    /// The strategy to use for encoding maps.
    public enum MapEncodingStrategy {
        /// The output will contain a single header for
        /// each entry of the map. This is the default.
        /// ie. QueryInput(theMap: ["Key": "Value"]) --> ?theMap.Key=Value
        /// Matches the decoding strategy `QueryDecoder.MapEncodingStrategy.singleQueryEntry`.
        case singleQueryEntry

        /// The output will contain separate headers for the key and value
        /// of each entry of the map, specified as a list.
        /// ie. QueryInput(theMap: ["Key": "Value"]) --> ?theMap.1.KeyTag=Key&theMap.1.ValueTag=Value
        /// Matches the decoding strategy `QueryDecoder.MapEncodingStrategy.separateQueryEntriesWith`.
        case separateQueryEntriesWith(keyTag: String, valueTag: String)
        
        var shapeMapEncodingStrategy: ShapeMapEncodingStrategy {
            switch self {
            case .singleQueryEntry:
                return .singleShapeEntry
            case let .separateQueryEntriesWith(keyTag: keyTag, valueTag: valueTag):
                return .separateShapeEntriesWith(keyTag: keyTag, valueTag: valueTag)
            }
        }
    }
    
    /// The strategy to use when encoding lists.
    public enum ListEncodingStrategy {
        /// The index of the item in the list will be used as
        /// the tag for each individual item. This is the default strategy.
        /// ie. ShapeOutput(theList: ["Value"]) --> ?theList.1=Value
        case expandListWithIndex
        
        /// The item tag will used as as the tag in addition to the index of the item in the list.
        /// ie. ShapeOutput(theList: ["Value"]) --> ?theList.ItemTag.1=Value
        case expandListWithIndexAndItemTag(itemTag: String)
        
        var shapeListEncodingStrategy: ShapeListEncodingStrategy {
            switch self {
            case .expandListWithIndex:
                return .expandListWithIndex
            case let .expandListWithIndexAndItemTag(itemTag: itemTag):
                return .expandListWithIndexAndItemTag(itemTag: itemTag)
            }
        }
    }
    
    /**
     Initializer.
     
     - Parameters:
        - keyEncodingStrategy: the `KeyEncodingStrategy` to use for encoding.
                               By default uses `.useAsShapeSeparator(".")`.
        - mapEncodingStrategy: the `MapEncodingStrategy` to use for encoding.
                               By default uses `.singleQueryEntry`.
        - KeyEncodeTransformStrategy: the `KeyEncodeTransformStrategy` to use for transforming keys.
                               By default uses `.none`.
     */
    public init(keyEncodingStrategy: KeyEncodingStrategy = .useAsShapeSeparator("."),
                mapEncodingStrategy: MapEncodingStrategy = .singleQueryEntry,
                listEncodingStrategy: ListEncodingStrategy = .expandListWithIndex,
                keyEncodeTransformStrategy: KeyEncodeTransformStrategy = .none) {
        self.options = StandardEncodingOptions(
            shapeKeyEncodingStrategy: keyEncodingStrategy,
            shapeMapEncodingStrategy: mapEncodingStrategy.shapeMapEncodingStrategy,
            shapeListEncodingStrategy: listEncodingStrategy.shapeListEncodingStrategy,
            shapeKeyEncodeTransformStrategy: keyEncodeTransformStrategy)
    }

    /**
     Encode the provided value.

     - Parameters:
        - value: The value to be encoded
        - allowedCharacterSet: The allowed character set for query values. If nil,
          all characters are allowed.
        - userInfo: The user info to use for this encoding.
     */
    public func encode<T: Swift.Encodable>(_ value: T,
                                           allowedCharacterSet: CharacterSet? = nil,
                                           userInfo: [CodingUserInfoKey: Any] = [:]) throws -> String {
        let delegate = StandardShapeSingleValueEncodingContainerDelegate(options: options)
        let container = ShapeSingleValueEncodingContainer(
            userInfo: userInfo,
            codingPath: [],
            delegate: delegate,
            allowedCharacterSet: allowedCharacterSet,
            defaultValue: nil)
        try value.encode(to: container)

        var elements: [(String, String?)] = []
        try container.getSerializedElements(nil, isRoot: true, elements: &elements)

        // The query elements need to be sorted into canonical form
        let sortedElements = elements.sorted { (left, right) in left.0.lowercased() < right.0.lowercased() }

        return sortedElements.map { (key, value) in
            if let theString = value {
                return "\(key)=\(theString)"
            } else {
                return key
            }
        }.joined(separator: "&")
    }
}
