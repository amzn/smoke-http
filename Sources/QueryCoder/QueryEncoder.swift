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
//  QueryEncoder.swift
//  QueryCoder
//

import Foundation

public enum QueryEncoderError: Error {
    case typeNotQueryCompatible(String)
}

///
/// Encode Swift types into query strings.
///
/// Nested types, arrays and dictionaries are serialized into query keys using a '.' notation.
/// Array entries are indicated by a 1-based index
/// ie. QueryOutput(theArray: ["Value1", "Value2"]) --> ?theArray.1=Value1&theArray.2=Value2
/// Nested type attributes are indicated by the attribute keys
/// ie. QueryOutput(theType: TheType(foo: "Value1", bar: "Value2")) --> ?theType.foo=Value1&theType.bar=Value2
/// Dictionary entries are indicated based on the provided `MapEncodingStrategy`
///
/// This matches the default query key decoding strategy QueryDecoder.queryKeyDecodingStrategy.useDotAsContainerSeparator`.
public class QueryEncoder {

    /// The strategy to use for encoding maps.
    public enum MapEncodingStrategy {
        /// The query output will contain a single query entry for
        /// each entry of the map. This is the default.
        /// ie. QueryOutput(theMap: ["Key": "Value"]) --> ?theMap.Key=Value
        case singleQueryEntry

        /// The query output will contain separate entries for the key and value
        /// of each entry of the map, specified as a list.
        /// ie. QueryOutput(theMap: ["Key": "Value"]) --> ?theMap.1.KeyTag=Key&theMap.1.ValueTag=Value
        case separateQueryEntriesWith(keyTag: String, valueTag: String)
    }

    internal struct Options {
        let mapEncodingStrategy: MapEncodingStrategy
    }

    internal let options: Options

    public init(mapEncodingStrategy: MapEncodingStrategy = .singleQueryEntry) {
        self.options = Options(mapEncodingStrategy: mapEncodingStrategy)
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
        let container = QuerySingleValueEncodingContainer(userInfo: userInfo,
                                                          codingPath: [], options: options,
                                                          allowedCharacterSet: allowedCharacterSet,
                                                          defaultValue: nil)
        try value.encode(to: container)

        var elements: [String: String] = [:]
        try container.getQueryElements(nil, isRoot: true, elements: &elements)

        // The query elements need to be sorted into canonical form
        let sortedElements = elements.sorted { (left, right) in left.key.lowercased() < right.key.lowercased() }

        return sortedElements.map { (key, value) in "\(key)=\(value)"}
                             .joined(separator: "&")
    }
}

internal protocol QueryElement {
    func getQueryElements(_ key: String?, isRoot: Bool, elements: inout [String: String]) throws
}

extension String: QueryElement {
    func getQueryElements(_ key: String?, isRoot: Bool, elements: inout [String: String]) throws {
        if let key = key {
            elements[key] = self
        } else {
            throw QueryEncoderError.typeNotQueryCompatible("String cannot be used as a query element without a key")
        }
    }
}

internal enum ContainerValueType {
    case singleValue(QueryElement)
    case unkeyedContainer([QueryElement])
    case keyedContainer([String: QueryElement])
}
