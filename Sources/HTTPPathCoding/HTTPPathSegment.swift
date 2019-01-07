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
//  HTTPPathSegment.swift
//  HTTPPathCoding
//

import Foundation

public enum HTTPPathErrors: Error {
    case hasEmptySegment
    case hasInvalidMultiSegmentTokens
    case hasAdjoiningVariables
}

public struct HTTPPathSegment: Equatable {
    public let tokens: [HTTPPathToken]
    
    private static let segmentsSeparator: Character = "/"
    
    public init(tokens: [HTTPPathToken]) {
        self.tokens = tokens
    }
    
    public static func getPathSegmentsForPath(uri: String) -> [String] {
        return Array(uri.split(separator: segmentsSeparator)
            .map(String.init))
    }
    
    /**
     Tokenizes the provided template string into an array of path segments.
 
     - Parameters:
        - template: the template to tokenize.
     - Returns: the array of path segments.
     */
    public static func tokenize(template: String) throws -> [HTTPPathSegment] {
        let segmentStrings = template.split(separator: "/",
                                            omittingEmptySubsequences: false)
        
        var firstSegment = true
        let segments: [HTTPPathSegment] = try segmentStrings.compactMap { segmentString in
            guard !segmentString.isEmpty else {
                if !firstSegment {
                    throw HTTPPathErrors.hasEmptySegment
                } else {
                    return nil
                }
            }
            
            firstSegment = false
            
            let tokens = try HTTPPathToken.tokenize(template: String(segmentString))
            
            return HTTPPathSegment(tokens: tokens)
        }
        
        let invalidMultiSegments = segments.dropLast().filter { segment in
            return segment.tokens.reduce(false) { (initial, current) in
                return initial || current.isMultiSegment
            }
        }
        
        guard invalidMultiSegments.isEmpty else {
            throw HTTPPathErrors.hasInvalidMultiSegmentTokens
        }
        
        return segments
    }
    
    /**
     Parses the provided value into an array of variables
     that match the tokens of this Path Segment.
     
     - Parameters:
         - value: the value to be parsed
         - variables: the array to place the discovered variables.
         - remainingSegmentValues: the values of any remaining unparsed path segments.
                                   To be used for greedy tokens.
        - isLastSegment: if this is the last segment in a path to be parsed.
     */
    public func parse(value: String,
                      variables: inout [(String, String?)],
                      remainingSegmentValues: inout [String],
                      isLastSegment: Bool) throws {
        var unparsedValue = value
        var currentVariableKey: String?
        var isGreedyToken = false
        
        try tokens.forEach { token in
            switch token {
            case .string(let value):
                // if there was a variable before this
                if let variableKey = currentVariableKey {
                    let currentUnparsedValue = try getVariableValue(
                        rawVariableValue: unparsedValue,
                        remainingSegmentValues: &remainingSegmentValues,
                        isGreedyToken: isGreedyToken, isLastSegment: isLastSegment)
                    // the remaining path segment must have the value somewhere
                    guard let index = currentUnparsedValue.lowercased().range(of: value)?.lowerBound else {
                        throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate("Path does not have '\(value)' from template.")
                    }
                    
                    let variableValue = String(currentUnparsedValue[..<index])
                    variables.append((variableKey, variableValue))
                    unparsedValue = String(currentUnparsedValue.dropFirst(variableValue.count + value.count))
                } else {
                    // the remaining path segment must be prefixed by the value
                    guard unparsedValue.lowercased().hasPrefix(value) else {
                        throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate("Path does not have '\(value)' from template.")
                    }
                    
                    // drop the value from the remaining path to move on
                    unparsedValue = String(unparsedValue.dropFirst(value.count))
                }
                currentVariableKey = nil
            case .variable(let name, let isMultiSegment):
                currentVariableKey = name
                isGreedyToken = isMultiSegment
            }
        }
        
        // if there was a variable before this
        if let variableKey = currentVariableKey {
            let variableValue = try getVariableValue(
                rawVariableValue: unparsedValue,
                remainingSegmentValues: &remainingSegmentValues,
                isGreedyToken: isGreedyToken, isLastSegment: isLastSegment)
            variables.append((variableKey, variableValue))
        }
    }
    
    fileprivate func getVariableValue(rawVariableValue: String, remainingSegmentValues: inout [String],
                                      isGreedyToken: Bool, isLastSegment: Bool) throws -> String {
        let variableValue: String
        if remainingSegmentValues.isEmpty {
            variableValue = rawVariableValue
            // If this isn't a greedy token
        } else if !isGreedyToken {
            // There are remaining path segments but not a greedy token
            // and this is the last segment
            if isLastSegment {
                throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate("Too many segments in path compared with template.")
            }
            
            variableValue = rawVariableValue
        } else {
            variableValue = rawVariableValue + "/" + remainingSegmentValues.joined(separator: "/")
            
            // the remaing segment values have been used, consume them
            remainingSegmentValues = []
        }
        
        return variableValue
    }
}
