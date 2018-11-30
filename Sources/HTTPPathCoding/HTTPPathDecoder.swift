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
//  HTTPPathDecoder.swift
//  QueryCoder
//

import Foundation
import ShapeCoding

public enum HTTPPathDecoderErrors: Error {
    case pathDoesNotMatchTemplate
}

/**
 Decode query strings into Swift types.
 */
public struct HTTPPathDecoder {
    private let options: StandardDecodingOptions
    private let userInfo: [CodingUserInfoKey: Any]
    
    public typealias KeyDecodingStrategy = ShapeKeyDecodingStrategy
    
    let queryPrefix: Character = "?"
    let valuesSeparator: Character = "&"
    let equalsSeparator: Character = "="
    
    /**
     Initializer.
     */
    public init(userInfo: [CodingUserInfoKey: Any] = [:],
                keyDecodingStrategy: KeyDecodingStrategy = .useAsShapeSeparator(".")) {
        self.options = StandardDecodingOptions(shapeKeyDecodingStrategy: keyDecodingStrategy,
                                               shapeMapDecodingStrategy: .singleShapeEntry)
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
    public func decode<T: Decodable>(_ type: T.Type, from path: String,
                                     withTemplate template: String) throws -> T {
        var remainingPathSegments = Array(path.split(separator: "/")
            .map(String.init).reversed())
        var remainingTemplateSegments =
            try Array(HTTPPathSegment.tokenize(template: template).reversed())
        var variables: [(String, String?)] = []
        
        // iterate through the path elements
        while let templateSegment = remainingTemplateSegments.popLast() {
            guard let pathSegment = remainingPathSegments.popLast() else {
                throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate
            }
            
            try parsePathSegment(templateSegment: templateSegment,
                             pathSegment: pathSegment,
                             variables: &variables,
                             remainingPathSegments: remainingPathSegments)
        }

        let stackValue = try StandardShapeParser.parse(with: variables, decoderOptions: options)
        
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
    
    func parsePathSegment(templateSegment: HTTPPathSegment,
                          pathSegment: String,
                          variables: inout [(String, String?)],
                          remainingPathSegments: [String]) throws {
        var remaingPathSegment = pathSegment
        var currentVariableKey: String?
        
        try templateSegment.tokens.forEach { token in
            switch token {
            case .string(let value):
                // if there was a variable before this
                if let variableKey = currentVariableKey {
                    // the remaining path segment must have the value somewhere
                    guard let index = remaingPathSegment.range(of: value)?.lowerBound else {
                        throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate
                    }
                    
                    let variableValue = String(remaingPathSegment[..<index])
                    variables.append((variableKey, variableValue))
                    remaingPathSegment = String(remaingPathSegment.dropFirst(variableValue.count + value.count))
                } else {
                    // the remaining path segment must be prefixed by the value
                    guard remaingPathSegment.hasPrefix(value) else {
                        throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate
                    }
                    
                    // drop the value from the remaining path to move on
                    remaingPathSegment = String(remaingPathSegment.dropFirst(value.count))
                }
            case .variable(let name, _):
                currentVariableKey = name
            }
        }
        
        // if there was a variable before this
        if let variableKey = currentVariableKey {
            let variableValue = remaingPathSegment
            variables.append((variableKey, variableValue))
        }
    }
}
