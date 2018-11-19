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
//  StandardShapeParser.swift
//  ShapeCoding
//

import Foundation

/// Parses a [String: String] into an Shape structure.
public struct StandardShapeParser {
    let storage = ShapeDecodingStorage()
    var rootShape: NestedableMutableShape?
    var codingPath: [CodingKey] = []
    
    let decoderOptions: StandardDecodingOptions
    
    private init(decoderOptions: StandardDecodingOptions) {
        self.decoderOptions = decoderOptions
    }
    
    /// Parses a query into an Shape structure.
    public static func parse(with headers: [(String, String?)], decoderOptions: StandardDecodingOptions) throws -> Shape {
        
        var parser = StandardShapeParser(decoderOptions: decoderOptions)
        try parser.parse(shapeName: nil, with: headers)
        
        return parser.rootShape?.asShape() ?? .null
    }
    
    mutating func parse(shapeName: String?, with entries: [(String, String?)]) throws {
        // create a dictionary for the array
        let mutableShapeDictionary = MutableShapeDictionary()

        // either this is the root shape or
        // add it to the current shape
        if rootShape == nil {
            rootShape = .dictionary(mutableShapeDictionary)
        } else {
            try addChildMutableShape(shapeName: shapeName, mutableShape: .dictionary(mutableShapeDictionary))
        }
        
        // add as the new top shape
        storage.push(shape: .dictionary(mutableShapeDictionary))
        
        switch decoderOptions.shapeKeyDecodingStrategy {
        case .flatStructure, .useShapePrefix:
            try parseWithoutShapeSeparator(with: entries)
        case .useAsShapeSeparator(let separatorCharacter):
            try parseWithShapeSeparator(with: entries,
                                            separatorCharacter: separatorCharacter)
        }
        
        // remove the top shape
        storage.popShape()
    }
    
    mutating func parseWithoutShapeSeparator(with entries: [(String, String?)]) throws {
        try entries.forEach { try addEntry($0) }
    }
    
    mutating func parseWithShapeSeparator(with entries: [(String, String?)],
                                          separatorCharacter: Character) throws {
        var nonNestedShapeEntries: [(String, String?)] = []
        var nestedShapeEntries: [String: [(String, String?)]] = [:]
        
        entries.forEach { entry in
            let components = entry.0.split(separator: separatorCharacter, maxSplits: 1, omittingEmptySubsequences: true)
            
            // if this is part of a nested shape
            if components.count > 1 {
                // add to the nested shape
                let shapeName = String(components[0])
                let nestedEntryName = String(components[1])
                if var currentShape = nestedShapeEntries[shapeName] {
                    currentShape.append((nestedEntryName, entry.1))
                    nestedShapeEntries[shapeName] = currentShape
                } else {
                    nestedShapeEntries[shapeName] = [(nestedEntryName, entry.1)]
                }
            } else {
                nonNestedShapeEntries.append(entry)
            }
        }
        
        // add any non nested shape entries as normal
        try nonNestedShapeEntries.forEach { try addEntry($0) }
        
        // iterate through the nested shape entries
        try nestedShapeEntries.forEach { shape in
            try parse(shapeName: shape.key, with: shape.value)
        }
    }
    
    mutating func addEntry(_ entry: (String, String?)) throws {
        if let value = entry.1 {
            guard let removedPercentEncoding = value.removingPercentEncoding else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unable to remove percent encoding from value '\(value)'"))
            }
            try addChildMutableShape(shapeName: entry.0, mutableShape: .string(removedPercentEncoding))
        } else {
            try addChildMutableShape(shapeName: entry.0, mutableShape: .null)
        }
    }
    
    /// Add a child value to the shape
    mutating func addChildMutableShape(shapeName: String?, mutableShape: MutableShape) throws {
        if let topShape = storage.topShape {
            switch topShape {
            case .dictionary(let dictionary):
                guard let fieldName = shapeName else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Attempted to add to dictionary without a field name."))
                }

                // add to the existing dictionary
                dictionary[fieldName] = mutableShape
            }
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Attempted to add a child value without an enclosing shape"))
        }
    }
}