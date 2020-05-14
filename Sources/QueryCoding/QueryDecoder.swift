// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  QueryDecoder.swift
//  QueryCoding
//

import Foundation
import ShapeCoding

/**
 Decode query strings into Swift types.
 */
public struct QueryDecoder {
    private let options: StandardDecodingOptions
    private let userInfo: [CodingUserInfoKey: Any]
    
    public typealias KeyDecodingStrategy = ShapeKeyDecodingStrategy
    public typealias KeyDecodeTransformStrategy = ShapeKeyDecodeTransformStrategy
    
    /// The strategy to use for decoding maps.
    public enum MapDecodingStrategy {
        /// The decoder will expect a query entry for
        /// each entry of the map. This is the default.
        /// ie. ?theMap.Key=Value --> StackOutput(theMap: ["Key": "Value"])
        /// Matches the encoding strategy `QueryEncoder.MapDecodingStrategy.singleQueryEntry`.
        case singleQueryEntry

        /// The decoder will expect separate query entries for the key and value
        /// of each entry of the map, specified as a list.
        /// ie. ?theMap.1.KeyTag=Key&theMap.1.ValueTag=Value -> StackOutput(theMap: ["Key": "Value"])
        /// Matches the encoding strategy `QueryEncoder.MapDecodingStrategy.separateQueryEntriesWith`.
        case separateQueryEntriesWith(keyTag: String, valueTag: String)
        
        var shapeMapDecodingStrategy: ShapeMapDecodingStrategy {
            switch self {
            case .singleQueryEntry:
                return .singleShapeEntry
            case let .separateQueryEntriesWith(keyTag: keyTag, valueTag: valueTag):
                return .separateShapeEntriesWith(keyTag: keyTag, valueTag: valueTag)
            }
        }
    }
    
    /// The strategy to use when decoding lists.
    public enum ListDecodingStrategy {
        /// The index of the item in the list will be used as
        /// the tag for each individual item. This is the default strategy.
        /// ie. ?theList.1=Value -> ShapeOutput(theList: ["Value"])
        case collapseListWithIndex
        
        /// The item tag will used as as the tag in addition to the index of the item in the list.
        /// ie. ?theList.ItemTag.1=Value -> ShapeOutput(theList: ["Value"])
        case collapseListWithIndexAndItemTag(itemTag: String)
        
        var shapeListDecodingStrategy: ShapeListDecodingStrategy {
            switch self {
            case .collapseListWithIndex:
                return .collapseListWithIndex
            case let .collapseListWithIndexAndItemTag(itemTag: itemTag):
                return .collapseListWithIndexAndItemTag(itemTag: itemTag)
            }
        }
    }
    
    let queryPrefix: Character = "?"
    let valuesSeparator: Character = "&"
    let equalsSeparator: Character = "="
    
    /**
     Initializer.
     
     - Parameters:
        - keyDecodingStrategy: the `KeyDecodingStrategy` to use for decoding.
        - mapDecodingStrategy: the `MapDecodingStrategy` to use for decoding.
        - keyDecodeTransformStrategy: the `KeyDecodeTransformStrategy` to use for decoding.
     */
    public init(userInfo: [CodingUserInfoKey: Any] = [:],
                keyDecodingStrategy: KeyDecodingStrategy = .useAsShapeSeparator("."),
                mapDecodingStrategy: MapDecodingStrategy = .singleQueryEntry,
                listDecodingStrategy: ListDecodingStrategy = .collapseListWithIndex,
                keyDecodeTransformStrategy: KeyDecodeTransformStrategy = .none) {
        self.options = StandardDecodingOptions(
            shapeKeyDecodingStrategy: keyDecodingStrategy,
            shapeMapDecodingStrategy: mapDecodingStrategy.shapeMapDecodingStrategy,
            shapeListDecodingStrategy: listDecodingStrategy.shapeListDecodingStrategy,
            shapeKeyDecodeTransformStrategy: keyDecodeTransformStrategy)
        self.userInfo = userInfo
    }
    
    /**
     Decodes a string that represents an query string into an
     instance of the specified type.
 
     - Parameters:
        - type: The type of the value to decode.
        - query: The query string to decode.
     - returns: A value of the requested type.
     - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or
                if the given string is not a valid query.
     - throws: An error if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_ type: T.Type, from query: String) throws -> T {
        // if the query string starts with a '?'
        let valuesString: String
        
        if let first = query.first, first == queryPrefix {
            valuesString = String(query.dropFirst())
        } else {
            valuesString = query
        }
        
        let values = valuesString.split(separator: valuesSeparator,
                                        omittingEmptySubsequences: true)
        
        let entries: [(String, String?)] = values.map { value in String(value).separateOn(character: equalsSeparator) }
        
        let stackValue = try StandardShapeParser.parse(with: entries, decoderOptions: options)
        
        let decoder = ShapeDecoder(
            decoderValue: stackValue,
            isRoot: true,
            userInfo: userInfo,
            delegate: StandardShapeDecoderDelegate(options: options))
        
        guard let value = try decoder.unbox(stackValue, as: type, isRoot: true) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [],
                                                                          debugDescription: "The given data did not contain a top-level value."))
        }
        
        return value
    }
}

private extension String {
    func separateOn(character separator: Character) -> (String, String?) {
        let components = self.split(separator: separator, maxSplits: 1, omittingEmptySubsequences: true)
    
        let before = String(components[0])
        let after: String?
            
        if components.count > 1 {
            after = String(components[1])
        } else {
            after = nil
        }
        
        return (before, after)
    }
}
