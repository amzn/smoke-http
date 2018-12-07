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
    
    public init(tokens: [HTTPPathToken]) {
        self.tokens = tokens
    }
    
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
}
