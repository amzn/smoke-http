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
//  ShapeKeyedDecodingContainer.swift
//  ShapeCoding
//

import Foundation

// MARK: Decoding Containers
internal struct ShapeKeyedDecodingContainer<K: CodingKey> {
    typealias Key = K
    
    let decoder: ShapeDecoder
    let container: [String: Shape]
    private(set) public var codingPath: [CodingKey]
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    internal init(referencing decoder: ShapeDecoder,
                  wrapping container: [String: Shape],
                  isRoot: Bool) throws {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
        self.container = try decoder.delegate.getEntriesForKeyedContainer(
                wrapping: container,
                isRoot: isRoot,
                codingPath: decoder.codingPath)
    }
    
    internal init(referencing decoder: ShapeDecoder,
                  containerKey: CodingKey,
                  parentContainer: [String: Shape],
                  isRoot: Bool) throws {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
        self.container = try decoder.delegate.getEntriesForKeyedContainer(
                parentContainer: parentContainer,
                containerKey: containerKey,
                isRoot: isRoot,
                codingPath: decoder.codingPath)
    }
}
