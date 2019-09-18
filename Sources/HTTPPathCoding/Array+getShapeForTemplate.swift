// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  Array+getShapeForTemplate.swift
//  HTTPPathCoding
//

import Foundation
import ShapeCoding

public extension Array where Element == String {
    func getShapeForTemplate(
            templateSegments: [HTTPPathSegment],
            decoderOptions: StandardDecodingOptions = StandardDecodingOptions(
                shapeKeyDecodingStrategy: .useAsShapeSeparator("."),
                shapeMapDecodingStrategy: .singleShapeEntry,
                shapeKeyDecodeTransformStrategy: .none)) throws -> Shape {
        // reverse the arrays so we can use popLast to iterate in the forwards direction
        var remainingPathSegments = Array(self.reversed())
        var remainingTemplateSegments = [HTTPPathSegment](templateSegments.reversed())
        var variables: [(String, String?)] = []
        
        // iterate through the path elements
        while let templateSegment = remainingTemplateSegments.popLast() {
            guard let pathSegment = remainingPathSegments.popLast() else {
                throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate("Path has fewer segments than template.")
            }
            
            try templateSegment.parse(value: pathSegment,
                                      variables: &variables,
                                      remainingSegmentValues: &remainingPathSegments,
                                      isLastSegment: remainingTemplateSegments.isEmpty)
        }
        
        guard remainingPathSegments.isEmpty else {
            throw HTTPPathDecoderErrors.pathDoesNotMatchTemplate("Path has more segments than template.")
        }
        
        let stackValue = try StandardShapeParser.parse(with: variables,
                                                       decoderOptions: decoderOptions)
        
        return stackValue
    }
}
