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
//  StandardShapeSingleValueEncodingContainerDelegate.swift
//  ShapeCoding
//

import Foundation

/**
 A delegate type conforming to ShapeSingleValueEncodingContainerDelegate
 that will encode a shape using the options contained in StandardEncodingOptions.
 */
public struct StandardShapeSingleValueEncodingContainerDelegate:
ShapeSingleValueEncodingContainerDelegate {
    public let options: StandardEncodingOptions
    
    public init(options: StandardEncodingOptions) {
        self.options = options
    }
    
    public func serializedElementsForEncodingContainer(
            containerValue: ContainerValueType?,
            key: String?,
            isRoot: Bool,
            elements: inout [(String, String?)]) throws {
        // the encoding process must have placed a value in this container
        guard let containerValue = containerValue else {
            fatalError("Attempted to access uninitialized container.")
        }
        
        let separatorString = options.shapeKeyEncodingStrategy.separatorString

        switch containerValue {
        case .singleValue(let value):
            // get the serialized elements from the container value
            return try value.getSerializedElements(key, isRoot: false, elements: &elements)
        case .unkeyedContainer(let values):
            if let key = key {
                // for each of the values
                try values.enumerated().forEach { (index, value) in
                    let innerkey = "\(key)\(separatorString)\(index + 1)"
                    // get the serialized elements from this value
                    try value.getSerializedElements(innerkey, isRoot: false, elements: &elements)
                }
            } else {
                throw ShapeEncoderError.typeNotShapeCompatible("Lists cannot be used as a shape element without a key")
            }
        case .keyedContainer(let values):
            let sortedValues = values.sorted { (left, right) in left.key < right.key }

            try sortedValues.enumerated().forEach { entry in
                let innerKey = entry.element.key
                let index = entry.offset
                let keyToUse: String

                // if this isn't the root and using the separateShapeEntriesWith strategy
                if !isRoot, case let .separateShapeEntriesWith(keyTag: keyTag, valueTag: valueTag) = options.shapeMapEncodingStrategy {
                    let keyQueryElementKey: String
                    if let baseKey = key {
                        keyQueryElementKey = "\(baseKey)\(separatorString)\(index + 1)\(separatorString)\(keyTag)"
                        keyToUse = "\(baseKey)\(separatorString)\(index + 1)\(separatorString)\(valueTag)"
                    } else {
                        keyQueryElementKey = "\(index + 1)\(separatorString)\(keyTag)"
                        keyToUse = "\(index + 1)\(separatorString)\(valueTag)"
                    }

                    // add an element for the key
                    elements.append((keyQueryElementKey, innerKey))
                } else {
                    if let baseKey = key {
                        keyToUse = "\(baseKey)\(separatorString)\(innerKey)"
                    } else {
                        keyToUse = innerKey
                    }
                }

                // get the serialized elements from this value
                try entry.element.value.getSerializedElements(keyToUse, isRoot: false, elements: &elements)
            }
        }
    }
}
