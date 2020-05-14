// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  StandardShapeDecoderDelegate.swift
//  ShapeCoding
//

import Foundation

/**
 A delegate type conforming to ShapeDecoderDelegate that will decode a shape
 using the options contained in StandardDecodingOptions.
 */
public struct StandardShapeDecoderDelegate: ShapeDecoderDelegate {
    public let options: StandardDecodingOptions
    
    /**
     Initializer.
 
     - Parameters:
        - options: The options to use while decoding.
     */
    public init(options: StandardDecodingOptions) {
        self.options = options
    }
    
    public func getEntriesForKeyedContainer(
        parentContainer: [String: Shape],
        containerKey: CodingKey,
        isRoot: Bool,
        codingPath: [CodingKey]) throws -> [String: Shape] {
            // make sure there is an entry in the parent container for the provided key
            guard let value = parentContainer[containerKey.stringValue] else {
                let decodingContext = DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get nested keyed container -- no value found for key \"\(containerKey.stringValue)\"")
                throw DecodingError.keyNotFound(containerKey, decodingContext)
            }
        
            // make sure that entry is a dictionary
            guard case .dictionary(let container) = value else {
                throw DecodingError.typeMismatch(at: codingPath, expectation: [String: Any].self, reality: value)
            }
        
            // get the entries from the dictionary
            return try getEntriesForKeyedContainer(
                wrapping: container,
                isRoot: isRoot,
                codingPath: codingPath)
    }
    
    public func getEntriesForKeyedContainer(
        wrapping container: [String: Shape],
        isRoot: Bool,
        codingPath: [CodingKey]) throws -> [String: Shape] {
            let entries: [String: Shape]
            // for the root container, the container always uses the entries as provided
            if isRoot {
                entries = container
            } else {
                // based on the `shapeMapDecodingStrategy`
                switch options.shapeMapDecodingStrategy {
                case .singleShapeEntry:
                    // the container uses the entries as provided
                    entries = container
                case let .separateShapeEntriesWith(keyTag: keyTag, valueTag: valueTag):
                    // collapse the entries according to the keyTag and valueTag
                    entries = try getCollapsedContainerFromDictionary(
                        container: container,
                        keyTag: keyTag,
                        valueTag: valueTag,
                        codingPath: codingPath)
                }
            }
        
            return entries
    }
    
    public func getEntriesForUnkeyedContainer(
        parentContainer: [String: Shape],
        containerKey: CodingKey,
        isRoot: Bool,
        codingPath: [CodingKey]) throws -> [Shape] {
            // make sure there is an entry in the parent container for the provided key
            guard let value = parentContainer[containerKey.stringValue] else {
                let decodingContext = DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get nested unkeyed container -- no value found for key \"\(containerKey.stringValue)\"")
                throw DecodingError.keyNotFound(containerKey, decodingContext)
            }
        
            // make sure that entry is a dictionary
            guard case .dictionary(let container) = value else {
                throw DecodingError.typeMismatch(at: codingPath, expectation: [String: Any].self, reality: value)
            }
        
            // get the entries from the dictionary
            return try getEntriesForUnkeyedContainer(
                wrapping: container,
                isRoot: isRoot,
                codingPath: codingPath)
    }
    
    public func getEntriesForUnkeyedContainer(
        wrapping container: [String: Shape],
        isRoot: Bool,
        codingPath: [CodingKey]) throws -> [Shape] {
            var listContainer: [Shape] = []
            var entriesConsumed = 0
            let containerToUse: [String: Shape]
        
            // when there is an item tag for the list and a shape separator, the list has
            // already been broken down into a nested list
            switch (options.shapeListDecodingStrategy, options.shapeKeyDecodingStrategy) {
            case (.collapseListWithIndexAndItemTag(itemTag: let itemTag), .useAsShapeSeparator):
                // get the nested shape for the itemTag
                let (innerNestedValue, _) = try getNestedShape(
                    parentContainer: container,
                    containerKeyString: itemTag)
                // if no nested shape was found
                guard let value = innerNestedValue, case .dictionary(let innerContainer) = value else {
                    let debugDescription = "No value associated with key '\(itemTag)' in list of size \(container.count)."
                    let decodingContext = DecodingError.Context(codingPath: codingPath,
                                                                debugDescription: debugDescription)
                    throw DecodingError.keyNotFound(ShapeCodingKey(stringValue: itemTag, intValue: nil), decodingContext)
                }
                
                containerToUse = innerContainer
            default:
                containerToUse = container
            }
        
            // look for entries labelled with their index
            for index in 1...containerToUse.count {
                let valueKey: String
                
                switch options.shapeListDecodingStrategy {
                case .collapseListWithIndex:
                    valueKey = String(index)
                case let .collapseListWithIndexAndItemTag(itemTag: itemTag):
                    switch options.shapeKeyDecodingStrategy {
                    case .flatStructure, .useShapePrefix:
                        valueKey = "\(itemTag)\(index)"
                    case .useAsShapeSeparator:
                        valueKey = String(index)
                    }
                }
                
                // if all entries have been consumed
                guard entriesConsumed < containerToUse.count else {
                    break
                }
                
                // get the nested shape which may consume multiple entries
                let (nestedValue, nestedCount) = try getNestedShape(
                    parentContainer: containerToUse,
                    containerKeyString: valueKey)
                // if no nested shape was found
                guard let value = nestedValue else {
                    let debugDescription = "No value associated with key '\(valueKey)' in list of size \(container.count)."
                    let decodingContext = DecodingError.Context(codingPath: codingPath,
                                                                debugDescription: debugDescription)
                    throw DecodingError.keyNotFound(ShapeCodingKey(index: index), decodingContext)
                }
                
                listContainer.append(value)
                entriesConsumed += nestedCount
            }
        
            return listContainer
    }
    
    public func getNestedShape(parentContainer: [String: Shape],
                               containerKey: CodingKey) throws -> Shape? {
        let (nestedValue, _) = try getNestedShape(
            parentContainer: parentContainer,
            containerKeyString: containerKey.stringValue)
        
        return nestedValue
    }
    
    func getNestedShape(parentContainer: [String: Shape],
                        containerKeyString: String) throws -> (Shape?, Int) {
        switch options.shapeKeyDecodingStrategy {
        case .useShapePrefix:
            // if a value exists at the exact key
            if let value = parentContainer[containerKeyString] {
                // return it
                return (value, 1)
            }
            
            // otherwise construct a nested dictionary based on the prefix
            return try getNestedShape(parentContainer: parentContainer,
                                           withPrefix: containerKeyString)
        default:
            // if a value exists at the key
            if let value = parentContainer[containerKeyString] {
                // return it
                return (value, 1)
            } else {
                // nothing to return
                return (nil, 0)
            }
        }
    }
    
    func getNestedShape(parentContainer: [String: Shape],
                        withPrefix prefix: String) throws -> (Shape?, Int) {
        var innerDictionary: [String: Shape] = [:]
        
        parentContainer.forEach { (key, value) in
            guard key.hasPrefix(prefix) else {
                // can ignore
                return
            }
            
            // drop the prefix from the key and add to the nested shape dictionary
            let newKey = String(key.dropFirst(prefix.count))
            innerDictionary[newKey] = value
        }
        
        guard innerDictionary.count > 0 else {
            return (nil, 0)
        }
        
        return (.dictionary(innerDictionary), innerDictionary.count)
    }
    
    func getCollapsedContainerFromDictionary(container: [String: Shape],
                                             keyTag: String, valueTag: String,
                                             codingPath: [CodingKey]) throws -> [String: Shape] {
        var collapsedContainer: [String: Shape] = [:]
        
        var entriesConsumed = 0
        // look for entries labelled with their index
        for index in 1...container.count {
            let valueKey = String(index)
            let indexCodingKey = ShapeCodingKey(index: index)
                
            // if all entries have been consumed
            guard entriesConsumed < container.count else {
                break
            }
            
            // get the nested shape which should be a dictionary
            // containing the key and value entries
            let (nestedValue, nestedCount) = try getNestedShape(
                    parentContainer: container,
                    containerKeyString: valueKey)
            // if no nested shape was found
            guard let value = nestedValue else {
                let debugDescription = "No value associated with key '\(valueKey)' in list of size \(container.count)."
                let decodingContext = DecodingError.Context(codingPath: codingPath,
                                                            debugDescription: debugDescription)
                throw DecodingError.keyNotFound(indexCodingKey, decodingContext)
            }
            
            // check the returned value is a dictionary
            guard case let .dictionary(innerValues) = value else {
                let debugDescription = "Dictionary entry with key '\(valueKey)' is not itself a dictionary."
                let decodingContext = DecodingError.Context(codingPath: codingPath,
                                                            debugDescription: debugDescription)
                throw DecodingError.dataCorrupted(decodingContext)
            }
            
            // get the key value
            guard let keyValueShape = innerValues[keyTag] else {
                let debugDescription = "No value associated with key '\(keyTag)'."
                let decodingContext = DecodingError.Context(codingPath: codingPath + [indexCodingKey],
                                                            debugDescription: debugDescription)
                throw DecodingError.keyNotFound(ShapeCodingKey(index: index), decodingContext)
            }
            
            // the key should be a string
            guard case let .string(keyValue) = keyValueShape else {
                let debugDescription = "Dictionary key value with key '\(valueKey)' is not a string."
                let decodingContext = DecodingError.Context(codingPath: codingPath + [indexCodingKey],
                                                            debugDescription: debugDescription)
                throw DecodingError.dataCorrupted(decodingContext)
            }
            
            // get the actual value of the entry
            guard let valueValue = innerValues[valueTag] else {
                let debugDescription = "No value associated with key '\(valueTag)'."
                let decodingContext = DecodingError.Context(codingPath: codingPath + [indexCodingKey],
                                                            debugDescription: debugDescription)
                throw DecodingError.keyNotFound(ShapeCodingKey(index: index), decodingContext)
            }
            
            // add to the container dictionary
            collapsedContainer[keyValue] = valueValue
            entriesConsumed += nestedCount
        }
        
        return collapsedContainer
    }
}
