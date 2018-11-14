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
//  QueryStackParser.swift
//  QueryCoder
//

import Foundation

/// Parses a query string into an QueryValue structure.
internal struct QueryStackParser {
    let storage = QueryDecodingStorage()
    var rootContainer: MutableContainer?
    var codingPath: [CodingKey] = []
    
    let decoderOptions: QueryDecoder.Options
    
    private init(decoderOptions: QueryDecoder.Options) {
        self.decoderOptions = decoderOptions
    }
    
    static let queryPrefix: Character = "?"
    static let valuesSeparator: Character = "&"
    static let equalsSeparator: Character = "="
    static let dotCharacter: Character = "."
    
    /// Parses a query into an QueryValue structure.
    static func parse(with query: String, decoderOptions: QueryDecoder.Options) throws -> QueryValue {
        // if the query string starts with a '?'
        let valuesString: String
        
        if let first = query.first, first == queryPrefix {
            valuesString = String(query.dropFirst())
        } else {
            valuesString = query
        }
        
        let values = valuesString.split(separator: valuesSeparator,
                                        omittingEmptySubsequences: true)
        
        let entries: [(String, String?)] = values.map { value in String(value).separateOn(character: equalsSeparator) }
        
        var parser = QueryStackParser(decoderOptions: decoderOptions)
        try parser.parse(containerName: nil, with: entries)
        
        return parser.rootContainer?.asQueryValue() ?? .null
    }
    
    mutating func parse(containerName: String?, with entries: [(String, String?)]) throws {
        // create a dictionary for the array
        let mutableContainerDictionary = MutableContainerDictionary()

        // either this is the root container or
        // add it to the current container
        if rootContainer == nil {
            rootContainer = .dictionary(mutableContainerDictionary)
        } else {
            try addChildMutableQueryValue(containerName: containerName, mutableQueryValue: .dictionary(mutableContainerDictionary))
        }
        
        // add as the new top container
        storage.push(container: .dictionary(mutableContainerDictionary))
        
        switch decoderOptions.queryKeyDecodingStrategy {
        case .flatStructure:
            try parseWithoutDotContainerSeparator(with: entries)
        case .useDotAsContainerSeparator:
            try parseWithDotContainerSeparator(with: entries)
        }
        
        // remove the top container
        storage.popContainer()
    }
    
    mutating func parseWithoutDotContainerSeparator(with entries: [(String, String?)]) throws {
        try entries.forEach { try addEntry($0) }
    }
    
    mutating func parseWithDotContainerSeparator(with entries: [(String, String?)]) throws {
        var nonContaineredEntries: [(String, String?)] = []
        var containeredEntries: [String: [(String, String?)]] = [:]
        
        entries.forEach { entry in
            let components = entry.0.split(separator: QueryStackParser.dotCharacter, maxSplits: 1, omittingEmptySubsequences: true)
            
            // if this is part of a nested container
            if components.count > 1 {
                // add to the nested container
                let containerName = String(components[0])
                let nestedEntryName = String(components[1])
                if var currentContainer = containeredEntries[containerName] {
                    currentContainer.append((nestedEntryName, entry.1))
                    containeredEntries[containerName] = currentContainer
                } else {
                    containeredEntries[containerName] = [(nestedEntryName, entry.1)]
                }
            } else {
                nonContaineredEntries.append(entry)
            }
        }
        
        // add any non containered entries as normal
        try nonContaineredEntries.forEach { try addEntry($0) }
        
        // iterate through the containered entries
        try containeredEntries.forEach { container in
            try parse(containerName: container.key, with: container.value)
        }
    }
    
    mutating func addEntry(_ entry: (String, String?)) throws {
        if let value = entry.1 {
            guard let removedPercentEncoding = value.removingPercentEncoding else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unable to remove percent encoding from value '\(value)'"))
            }
            try addChildMutableQueryValue(containerName: entry.0, mutableQueryValue: .string(removedPercentEncoding))
        } else {
            try addChildMutableQueryValue(containerName: entry.0, mutableQueryValue: .null)
        }
    }
    
    /// Add a child value to the container
    mutating func addChildMutableQueryValue(containerName: String?, mutableQueryValue: MutableQueryValue) throws {
        if let topContainer = storage.topContainer {
            switch topContainer {
            case .dictionary(let dictionary):
                guard let fieldName = containerName else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Attempted to add to dictionary without a field name."))
                }

                // add to the existing dictionary
                dictionary[fieldName] = mutableQueryValue
            }
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Attempted to add a child value without an enclosing container"))
        }
    }
}

private extension String {
    func separateOn(character separator: Character) -> (String, String?) {
        let components = self.split(separator: separator, maxSplits: 1, omittingEmptySubsequences: true)
    
        let before = String(components[0])
        let after = components.count > 1 ? String(components[1]) : nil
        
        return (before, after)
    }
}
