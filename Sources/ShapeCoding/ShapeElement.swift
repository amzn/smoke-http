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
//  ShapeElement.swift
//  ShapeCoding
//

import Foundation

/**
 Errors that can be thrown when encoding a shape.
 */
public enum ShapeEncoderError: Error {
    case typeNotShapeCompatible(String)
}

/**
 Protocol that elements of a shape must conform to.
 */
public protocol ShapeElement {
    /**
     Function that gathers the serialized elements that are either this element or contained within this element.
 
     - Parameters:
         - key: the key for this element if any.
         - isRoot: if this element is the root of the type being encoded.
         - elements: the array to append elements from this element to.
     */
    func getSerializedElements(_ key: String?, isRoot: Bool, elements: inout [(String, String?)]) throws
    
    /**
     Function to return the `RawShape` instance that represents this `ShapeElement`.
 
     - Returns: the corresponding `RawShape` instance.
     */
    func asRawShape() throws -> RawShape
}

/// Conform String to the `ShapeElement` protocol such that it returns itself as
extension String: ShapeElement {
    public func getSerializedElements(_ key: String?, isRoot: Bool, elements: inout [(String, String?)]) throws {
        if let key = key {
            elements.append((key, self))
        } else {
            throw ShapeEncoderError.typeNotShapeCompatible("String cannot be used as a shape element without a key")
        }
    }
    
    public func asRawShape() throws -> RawShape {
        return .string(self)
    }
}

/**
 Enumeration of possible values of a container.
 */
public enum ContainerValueType {
    /// A single value that conforms to the `ShapeElement` protocol
    case singleValue(ShapeElement)
    /// an unkeyed container that has a list of values that conform to the `ShapeElement` protocol
    case unkeyedContainer([ShapeElement])
    /// a keyed container that has a dictionary of values that conform to the `ShapeElement` protocol
    case keyedContainer([String: ShapeElement])
}
