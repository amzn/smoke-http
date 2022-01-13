//
// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  ShapeSingleValueEncodingContainerDelegate.swift
//  ShapeCoding
//

import Foundation

/**
 Delegate class that provides custom logic for a ShapeSingleValueEncodingContainer.
 */
public protocol ShapeSingleValueEncodingContainerDelegate {
    /**
     Function that gathers the serialized elements for an encoding container.
 
     - Parameters:
         - containerValue: the value of the container if any
         - key: the key of the container if any.
         - isRoot: if this container is the root of the type being encoded.
         - elements: the array to append elements from this container to.
     */
    func serializedElementsForEncodingContainer(
        containerValue: ContainerValueType?,
        key: String?,
        isRoot: Bool,
        elements: inout [(String, String?)]) throws
    
    /**
     Function to return the `RawShape` instance that represents the provider `ContainerValueType`.
 
     - Parameters:
        - containerValue: the containerValue to return the `RawShape` for.
     - Returns: the corresponding `RawShape` instance.
     */
    func rawShapeForEncodingContainer(containerValue: ContainerValueType?) throws -> RawShape
}
