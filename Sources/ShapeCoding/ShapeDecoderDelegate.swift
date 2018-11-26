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
//  ShapeDecoderDelegate.swift
//  ShapeCoding
//

import Foundation

public protocol ShapeDecoderDelegate {
    
    func getEntriesForKeyedContainer(parentContainer: [String: Shape],
                                     containerKey: CodingKey,
                                     isRoot: Bool,
                                     codingPath: [CodingKey]) throws -> [String: Shape]
    
    func getEntriesForKeyedContainer(wrapping: [String: Shape],
                                     isRoot: Bool,
                                     codingPath: [CodingKey]) throws -> [String: Shape]
    
    func getEntriesForUnkeyedContainer(parentContainer: [String: Shape],
                                       containerKey: CodingKey,
                                       isRoot: Bool,
                                       codingPath: [CodingKey]) throws -> [Shape]
    
    func getEntriesForUnkeyedContainer(wrapping: [String: Shape],
                                       isRoot: Bool,
                                       codingPath: [CodingKey]) throws -> [Shape]
    
    func getNestedShape(parentContainer: [String : Shape],
                             containerKey: CodingKey) throws -> Shape?
}
