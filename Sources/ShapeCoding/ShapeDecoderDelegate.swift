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
//  ShapeDecoderDelegate.swift
//  ShapeCoding
//

import Foundation

/**
 Delegate type to provide custom logic for a ShapeDecoder.
 */
public protocol ShapeDecoderDelegate {
    
    /**
     Extension point that can provide custom logic for providing the entries
     for a keyed container that is being created.
 
     - Parameters:
        - parentContainer: the entries of the parent container.
        - containerKey: the key corresponding to the container the
                        entries are being retrieved for.
        - isRoot: if this container represents the root of the type being decoded.
        - codingPath: the coding path of the kayed container being created.
     - Returns: the dictionary of entries for the keyed container being created.
     */
    func getEntriesForKeyedContainer(parentContainer: [String: Shape],
                                     containerKey: CodingKey,
                                     isRoot: Bool,
                                     codingPath: [CodingKey]) throws -> [String: Shape]
    
    /**
     Extension point that can provide custom logic for providing the entries
     for a keyed container that is being created. This overload variant is
     called when there isn't a parent keyed container.
 
     - Parameters:
        - wrapping: the raw keyed entries of the container being created.
        - isRoot: if this container represents the root of the type being decoded.
        - codingPath: the coding path of the kayed container being created.
     - Returns: the dictionary of entries for the keyed container being created.
     */
    func getEntriesForKeyedContainer(wrapping: [String: Shape],
                                     isRoot: Bool,
                                     codingPath: [CodingKey]) throws -> [String: Shape]
    
    /**
     Extension point that can provide custom logic for providing the entries
     for an unkeyed container that is being created.
 
     - Parameters:
        - parentContainer: the entries of the parent container.
        - containerKey: the key corresponding to the container the
                        entries are being retrieved for.
        - isRoot: if this container represents the root of the type being decoded.
        - codingPath: the coding path of the kayed container being created.
     - Returns: the array of entries for the keyed container being created.
     */
    func getEntriesForUnkeyedContainer(parentContainer: [String: Shape],
                                       containerKey: CodingKey,
                                       isRoot: Bool,
                                       codingPath: [CodingKey]) throws -> [Shape]
    
    /**
     Extension point that can provide custom logic for providing the entries
     for an unkeyed container that is being created. This overload variant is
     called when there isn't a parent keyed container.
 
     - Parameters:
        - wrapping: the raw keyed entries of the container being created.
        - isRoot: if this container represents the root of the type being decoded.
        - codingPath: the coding path of the kayed container being created.
     - Returns: the dictionary of entries for the keyed container being created.
     */
    func getEntriesForUnkeyedContainer(wrapping: [String: Shape],
                                       isRoot: Bool,
                                       codingPath: [CodingKey]) throws -> [Shape]
    
    /**
     Extension point that retrieves the Shape instance from a dictionary
     of container entries for the specified key.
     
     - Parameters:
        - parentContainer: the entries of the parent container.
        - containerKey: the key corresponding to the entry the
                        Shape is being retrieved for.
     - Returns: Shape for the specified key or nil if there is no such Shape.
     */
    func getNestedShape(parentContainer: [String: Shape],
                        containerKey: CodingKey) throws -> Shape?
}
