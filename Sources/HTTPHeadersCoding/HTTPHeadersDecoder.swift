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
//  HTTPHeadersDecoder.swift
//  HTTPHeadersCoding
//

import Foundation
import ShapeCoding

/**
 Decode HTTP Headers into Swift types.
 */
public struct HTTPHeadersDecoder {
    private let options: StandardDecodingOptions
    private let userInfo: [CodingUserInfoKey: Any]
    
    public typealias KeyDecodingStrategy = ShapeKeyDecodingStrategy
    
    /// The strategy to use for decoding maps.
    public enum MapDecodingStrategy {
        /// The decoder will expect a header for
        /// each entry of the map. This is the default.
        /// ie. ["theMap.Key": "Value"] --> StackOutput(theMap: ["Key": "Value"])
        case singleHeader

        /// The decoder will expect separate headers for the key and value
        /// of each entry of the map, specified as a list.
        /// ie. ["theMap.1.KeyTag": "Key", "theMap.1.ValueTag": "Value"] -> StackOutput(theMap: ["Key": "Value"])
        case separateHeadersWith(keyTag: String, valueTag: String)
        
        var shapeMapDecodingStrategy: ShapeMapDecodingStrategy {
            switch self {
            case .singleHeader:
                return .singleShapeEntry
            case let .separateHeadersWith(keyTag: keyTag, valueTag: valueTag):
                return .separateShapeEntriesWith(keyTag: keyTag, valueTag: valueTag)
            }
        }
    }
    
    /**
     Initializer.
     */
    public init(userInfo: [CodingUserInfoKey: Any] = [:],
                keyDecodingStrategy: KeyDecodingStrategy = .useAsShapeSeparator("-"),
                mapDecodingStrategy: MapDecodingStrategy = .singleHeader) {
        self.options = StandardDecodingOptions(
            shapeKeyDecodingStrategy: keyDecodingStrategy,
            shapeMapDecodingStrategy: mapDecodingStrategy.shapeMapDecodingStrategy)
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
    public func decode<T: Decodable>(_ type: T.Type, from headers: [(String, String?)]) throws -> T {
        let stackValue = try StandardShapeParser.parse(with: headers, decoderOptions: options)
        
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
