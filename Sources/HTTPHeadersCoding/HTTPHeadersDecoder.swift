// Copyright 2018-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
    public typealias KeyDecodeTransformStrategy = ShapeKeyDecodeTransformStrategy
    
    /// The strategy to use for decoding maps.
    public enum MapDecodingStrategy {
        /// The decoder will expect a header for
        /// each entry of the map. This is the default.
        /// ie. ["theMap.Key": "Value"] --> StackOutput(theMap: ["Key": "Value"])
        /// Matches the encoding strategy `HTTPHeadersEncoder.MapDecodingStrategy.singleHeader`.
        case singleHeader

        /// The decoder will expect separate headers for the key and value
        /// of each entry of the map, specified as a list.
        /// ie. ["theMap.1.KeyTag": "Key", "theMap.1.ValueTag": "Value"] -> StackOutput(theMap: ["Key": "Value"])
        /// Matches the encoding strategy `HTTPHeadersEncoder.MapDecodingStrategy.separateHeadersWith`.
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
     
     - Parameters:
        - keyDecodingStrategy: the `KeyDecodingStrategy` to use for decoding.
        - mapDecodingStrategy: the `MapDecodingStrategy` to use for decoding.
        - keyDecodeTransformStrategy: the `KeyDecodeTransformStrategy` to use for decoding.
     */
    public init(userInfo: [CodingUserInfoKey: Any] = [:],
                keyDecodingStrategy: KeyDecodingStrategy = .useAsShapeSeparator("-"),
                mapDecodingStrategy: MapDecodingStrategy = .singleHeader,
                keyDecodeTransformStrategy: KeyDecodeTransformStrategy = .none) {
        self.options = StandardDecodingOptions(
            shapeKeyDecodingStrategy: keyDecodingStrategy,
            shapeMapDecodingStrategy: mapDecodingStrategy.shapeMapDecodingStrategy,
            shapeListDecodingStrategy: .collapseListWithIndex,
            shapeKeyDecodeTransformStrategy: keyDecodeTransformStrategy)
        self.userInfo = userInfo
    }
    
    /**
     Decodes an array that represents a set of HTTP Headers into an
     instance of the specified type.
 
     - Parameters:
        - type: The type of the value to decode.
        - headers: The headers to decode.
     - returns: A value of the requested type.
     - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted.
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
