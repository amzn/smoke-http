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
//  HTTPPathToken.swift
//  HTTPPathCoding
//

import Foundation

public enum HTTPPathToken {
    case string(String)
    case variable(name: String, multiSegment: Bool)
    
    static let startCharacter: Character = "{"
    static let endCharacter: Character = "}"
    
    public var isMultiSegment: Bool {
        switch self {
        case .string:
            return false
        case .variable(name: _, multiSegment: let multiSegment):
            return multiSegment
        }
    }
    
    public static func tokenize(template: String) throws -> [HTTPPathToken] {
        var remainingTemplate = template
        var inVariable = false
        var tokens: [HTTPPathToken] = []
        
        var hasGreedyToken = false
        repeat {
            let nextSplit = inVariable ? endCharacter : startCharacter
            let components = remainingTemplate.split(separator: nextSplit, maxSplits: 1,
                                                 omittingEmptySubsequences: false)
            
            let thisToken = components[0]
            let futureTokens = components.count > 1 ? String(components[1]) : ""
            
            if !thisToken.isEmpty {
                if inVariable {
                    // can only have greedy tokens at the end
                    if hasGreedyToken {
                        throw HTTPPathErrors.hasInvalidMultiSegmentTokens
                    }
                    
                    let tokenName: String
                    let multiSegment: Bool
                    if let last = thisToken.last, last == "+" {
                        tokenName = String(thisToken.dropLast())
                        multiSegment = true
                        hasGreedyToken = true
                    } else {
                        tokenName = String(thisToken)
                        multiSegment = false
                    }
                    tokens.append(.variable(name: tokenName, multiSegment: multiSegment))
                } else {
                    tokens.append(.string(String(thisToken.lowercased())))
                }
            } else if !tokens.isEmpty {
                throw HTTPPathErrors.hasAdjoiningVariables
            }
            
            inVariable = !inVariable
            remainingTemplate = futureTokens
        } while !remainingTemplate.isEmpty
        
        return tokens
    }
}

extension HTTPPathToken: Equatable {
    public static func == (lhs: HTTPPathToken, rhs: HTTPPathToken) -> Bool {
        switch (lhs, rhs) {
        case let (.string(leftString), .string(rightString)):
            return leftString == rightString
        case let (.variable(leftName, leftMultiSegment), .variable(rightName, rightMultiSegment)):
            return leftName == rightName && leftMultiSegment == rightMultiSegment
        default:
            return false
        }
    }
}
