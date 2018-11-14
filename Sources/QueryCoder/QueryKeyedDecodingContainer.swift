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
//  QueryKeyedDecodingContainer.swift
//  QueryCoder
//

import Foundation

// MARK: Decoding Containers
internal struct QueryKeyedDecodingContainer<K: CodingKey> {
    typealias Key = K
    
    let decoder: InternalQueryDecoder
    let container: [String: QueryValue]
    private(set) public var codingPath: [CodingKey]
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    internal init(referencing decoder: InternalQueryDecoder, wrapping container: [String: QueryValue],
                  isRoot: Bool) throws {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
        
        if isRoot {
            self.container = container
        } else {
            switch decoder.options.mapDecodingStrategy {
            case .singleQueryEntry:
                self.container = container
            case let .separateQueryEntriesWith(keyTag: keyTag, valueTag: valueTag):
                self.container = try QueryKeyedDecodingContainer.getCollapsedContainerFromDictionary(
                    container: container,
                    keyTag: keyTag,
                    valueTag: valueTag,
                    codingPath: decoder.codingPath)
            }
        }
    }
    
    private static func getCollapsedContainerFromDictionary(container: [String: QueryValue],
                                                            keyTag: String, valueTag: String,
                                                            codingPath: [CodingKey]) throws -> [String: QueryValue] {
        var collapsedContainer: [String: QueryValue] = [:]
        for index in 1...container.count {
            let valueKey = String(index)
            let indexCodingKey = QueryCodingKey(index: index)
            
            guard let value = container[valueKey] else {
                let debugDescription = "No value associated with key '\(valueKey)' in list of size \(container.count)."
                let decodingContext = DecodingError.Context(codingPath: codingPath,
                                                            debugDescription: debugDescription)
                throw DecodingError.keyNotFound(indexCodingKey, decodingContext)
            }
            
            guard case let .dictionary(innerValues) = value else {
                let debugDescription = "Dictionary entry with key '\(valueKey)' is not itself a dictionary."
                let decodingContext = DecodingError.Context(codingPath: codingPath,
                                                            debugDescription: debugDescription)
                throw DecodingError.dataCorrupted(decodingContext)
            }
            
            guard let keyQueryValue = innerValues[keyTag] else {
                let debugDescription = "No value associated with key '\(keyTag)'."
                let decodingContext = DecodingError.Context(codingPath: codingPath + [indexCodingKey],
                                                            debugDescription: debugDescription)
                throw DecodingError.keyNotFound(QueryCodingKey(index: index), decodingContext)
            }
            
            guard case let .string(keyValue) = keyQueryValue else {
                let debugDescription = "Dictionary key value with key '\(valueKey)' is not a string."
                let decodingContext = DecodingError.Context(codingPath: codingPath + [indexCodingKey],
                                                            debugDescription: debugDescription)
                throw DecodingError.dataCorrupted(decodingContext)
            }
            
            guard let valueValue = innerValues[valueTag] else {
                let debugDescription = "No value associated with key '\(valueTag)'."
                let decodingContext = DecodingError.Context(codingPath: codingPath + [indexCodingKey],
                                                            debugDescription: debugDescription)
                throw DecodingError.keyNotFound(QueryCodingKey(index: index), decodingContext)
            }
            
            collapsedContainer[keyValue] = valueValue
        }
        
        return collapsedContainer
    }
}
