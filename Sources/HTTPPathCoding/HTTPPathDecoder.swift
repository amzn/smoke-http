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
//  HTTPPathDecoder.swift
//  HTTPPathCoding
//

import Foundation
import ShapeCoding

public enum HTTPPathDecoderErrors: Error {
    case pathDoesNotMatchTemplate(String)
}

/**
 Decode HTTP path strings into Swift types.
 */
public struct HTTPPathDecoder {
    private let options: StandardDecodingOptions
    private let userInfo: [CodingUserInfoKey: Any]
    
    public typealias KeyDecodingStrategy = ShapeKeyDecodingStrategy
    public typealias KeyDecodeTransformStrategy = ShapeKeyDecodeTransformStrategy
    
    /**
     Initializer.
     
     - Parameters:
        - keyDecodingStrategy: the `KeyDecodingStrategy` to use for decoding.
        - keyDecodeTransformStrategy: the `KeyDecodeTransformStrategy` to use for decoding.
     */
    public init(userInfo: [CodingUserInfoKey: Any] = [:],
                keyDecodingStrategy: KeyDecodingStrategy = .useAsShapeSeparator("."),
                keyDecodeTransformStrategy: KeyDecodeTransformStrategy = .none) {
        self.options = StandardDecodingOptions(
            shapeKeyDecodingStrategy: keyDecodingStrategy,
            shapeMapDecodingStrategy: .singleShapeEntry,
            shapeKeyDecodeTransformStrategy: keyDecodeTransformStrategy)
        self.userInfo = userInfo
    }
    
    /**
     Decodes a string that represents a HTTP path into an
     instance of the specified type.
 
     - Parameters:
        - type: The type of the value to decode.
        - path: The HTTP path to decode.
        - withTemplate: The path template to use to decode the path from.
     - returns: A value of the requested type.
     - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or
                if the given string is not a valid HTTP path.
     - throws: An error if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_ type: T.Type, from path: String,
                                     withTemplate template: String) throws -> T {
        let pathSegments = HTTPPathSegment.getPathSegmentsForPath(uri: path)
        let templateSegments = try HTTPPathSegment.tokenize(template: template)
        let shape = try pathSegments.getShapeForTemplate(templateSegments: templateSegments,
                                                         decoderOptions: options)
        
        let decoder = ShapeDecoder(
            decoderValue: shape,
            isRoot: true,
            userInfo: userInfo,
            delegate: StandardShapeDecoderDelegate(options: options))
        
        guard let value = try decoder.unbox(shape, as: type, isRoot: true) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [],
                                                                          debugDescription: "The given data did not contain a top-level value."))
        }
        
        return value
    }
    
    /**
     Decodes a decoded Shape into an instance of the specified type.
 
     - Parameters:
        - type: The type of the value to decode.
        - pathShape: Shape constructed from the path.
     - returns: A value of the requested type.
     - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or
                if the given string is not a valid HTTP path.
     - throws: An error if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_ type: T.Type, fromShape pathShape: Shape) throws -> T {
        let decoder = ShapeDecoder(
            decoderValue: pathShape,
            isRoot: true,
            userInfo: userInfo,
            delegate: StandardShapeDecoderDelegate(options: options))
        
        guard let value = try decoder.unbox(pathShape, as: type, isRoot: true) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [],
                                                                          debugDescription: "The given data did not contain a top-level value."))
        }
        
        return value
    }
}
