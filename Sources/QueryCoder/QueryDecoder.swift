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
//  QueryDecoder.swift
//  QueryCoder
//

import Foundation

/**
 Decode query strings into Swift types.
 */
public struct QueryDecoder {
    private let options: Options
    private let userInfo: [CodingUserInfoKey: Any]
    
    /// The strategy to use for decoding query keys.
    public enum QueryKeyDecodingStrategy {
        /// The decoder will spilt query keys on the '.' character to indicate a
        /// nested structure that could include nested types, dictionaries and arrays. This is the default.
        ///
        /// Array entries are indicated by a 1-based index
        /// ie. ?theArray.1=Value1&theArray.2=Value2 --> QueryOutput(theArray: ["Value1", "Value2"])
        /// Nested type attributes are indicated by the attribute keys
        /// ie. ?theType.foo=Value1&theType.bar=Value2 --> QueryOutput(theType: TheType(foo: "Value1", bar: "Value2"))
        /// Dictionary entries are indicated based on the provided `MapDecodingStrategy`
        case useDotAsContainerSeparator
        
        /// The decoder will decode query keys into the attributes
        /// of the provided type. No nested types, lists or dictionaries are possible.
        case flatStructure
    }
    
    /// The strategy to use for decoding maps.
    public enum MapDecodingStrategy {
        /// The decoder will expect a single query entry for
        /// each entry of the map. This is the default.
        /// ie. ?theMap.Key=Value --> QueryOutput(theMap: ["Key": "Value"])
        case singleQueryEntry

        /// The decoder will expect separate entries for the key and value
        /// of each entry of the map, specified as a list.
        /// ie. ?theMap.1.KeyTag=Key&theMap.1.ValueTag=Value -> QueryOutput(theMap: ["Key": "Value"])
        case separateQueryEntriesWith(keyTag: String, valueTag: String)
    }
    
    // Structure that hold the options to use during decoding
    internal struct Options {
        let queryKeyDecodingStrategy: QueryKeyDecodingStrategy
        let mapDecodingStrategy: MapDecodingStrategy
    }
    
    /**
     Initializer.
     */
    public init(userInfo: [CodingUserInfoKey: Any] = [:],
                queryKeyDecodingStrategy: QueryKeyDecodingStrategy = .useDotAsContainerSeparator,
                mapDecodingStrategy: MapDecodingStrategy = .singleQueryEntry) {
        self.options = Options(queryKeyDecodingStrategy: queryKeyDecodingStrategy,
                                mapDecodingStrategy: mapDecodingStrategy)
        self.userInfo = userInfo
    }
    
    /**
     Decodes a string that represents an query string into an
     instance of the specified type.
 
     - Parameters:
        - type: The type of the value to decode.
        - data: The data to decode from.
     - returns: A value of the requested type.
     - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or
                if the given string is not a valid query.
     - throws: An error if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_ type: T.Type, from query: String) throws -> T {
        let queryValue = try QueryStackParser.parse(with: query, decoderOptions: options)
        
        let decoder = InternalQueryDecoder(decoderValue: queryValue, isRoot: true, userInfo: userInfo,
                                  options: self.options)
        
        guard let value = try decoder.unbox(queryValue, as: type, isRoot: true) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [],
                                                                          debugDescription: "The given data did not contain a top-level value."))
        }
        
        return value
    }
}
