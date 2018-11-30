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
//  HTTPPathEncoder.swift
//  HTTPPathCoding
//

import Foundation
import ShapeCoding

///
/// Encode Swift types into HTTP paths.
///
/// Nested types, arrays and dictionaries are serialized into path tokens using a '.' notation.
/// Array entries are indicated by a 1-based index
/// ie. PathInput(theArray: ["Value1", "Value2"]) --> \base\{theArray.1}\{theArray.2}--> \base\Value1\Value2
/// Nested type attributes are indicated by the attribute keys
/// ie. PathInput(theType: TheType(foo: "Value1", bar: "Value2")) --> \base\{theType.1}\{theType.2}--> \base\Value1\Value2
/// Dictionary entries are indicated based on the provided `MapEncodingStrategy`
public class HTTPPathEncoder {
    internal let options: StandardEncodingOptions
    
    public typealias KeyEncodingStrategy = ShapeKeyEncodingStrategy

    public init(keyEncodingStrategy: KeyEncodingStrategy = .useAsShapeSeparator(".")) {
        self.options = StandardEncodingOptions(shapeKeyEncodingStrategy: keyEncodingStrategy,
                                               shapeMapEncodingStrategy: .singleShapeEntry)
    }

    /**
     Encode the provided value.

     - Parameters:
        - value: The value to be encoded
        - withTemplate: The path template to use to encode the value into.
        - userInfo: The user info to use for this encoding.
     */
    public func encode<T: Swift.Encodable>(_ value: T,
                                           withTemplate template: String,
                                           userInfo: [CodingUserInfoKey: Any] = [:]) throws -> String {
        let resultPrefix: String
        if let first = template.first, first == "/" {
            resultPrefix = "/"
        } else {
            resultPrefix = ""
        }
        
        let delegate = StandardShapeSingleValueEncodingContainerDelegate(options: options)
        let container = ShapeSingleValueEncodingContainer(
            userInfo: userInfo,
            codingPath: [],
            delegate: delegate,
            allowedCharacterSet: nil,
            defaultValue: nil)
        try value.encode(to: container)

        var elements: [(String, String?)] = []
        try container.getSerializedElements(nil, isRoot: true, elements: &elements)
        
        var mappedElements: [String: String] = [:]
        elements.forEach { element in
            if let value = element.1 {
                mappedElements[element.0] = value
            }
        }
        
        let pathSegments = try HTTPPathSegment.tokenize(template: template)
        
        return try resultPrefix + pathSegments.map { segment in
            return try getSegmentAsString(segment: segment, mappedElements: mappedElements)
        }.joined(separator: "/")
    }
    
    func getSegmentAsString(segment: HTTPPathSegment,
                            mappedElements: [String: String]) throws -> String {
        let pathElements = segment.tokens
        let mappedPathElements: [String] = try pathElements.map { element in
            switch element {
            case .string(let value):
                return value
            case .variable(let value, _):
                guard let substitutedValue = mappedElements[value] else {
                    let debugDescription = "Type did not have a value at \(value) for path."
                    let context = DecodingError.Context(codingPath: [],
                                                        debugDescription: debugDescription)
                    throw DecodingError.valueNotFound(String.self, context)
                }
                
                return substitutedValue
            }
        }

        return mappedPathElements.joined(separator: "")
    }
}
