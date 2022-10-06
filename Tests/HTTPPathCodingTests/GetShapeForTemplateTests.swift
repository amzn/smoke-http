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
//  GetShapeForTemplateTests.swift
//  HTTPPathCodingTests
//

import XCTest
@testable import HTTPPathCoding
import ShapeCoding

class GetShapeForTemplateTests: XCTestCase {
    
    func verifySuccessfulShape(template: String, path: String) throws {
        let templateSegments = try HTTPPathSegment.tokenize(template: template)
        let pathSegments = HTTPPathSegment.getPathSegmentsForPath(uri: path)
        
        let expected: [String: Shape] = ["id": .string("cat"),
                                         "index": .string("23")]
        
        let shape: Shape
        do {
            shape = try pathSegments.getShapeForTemplate(templateSegments: templateSegments)
        } catch {
            return XCTFail()
        }
        
        guard case let .dictionary(values) = shape else {
            return XCTFail()
        }
        
        XCTAssertEqual(expected, values)
    }
    
    func verifyUnsuccessfulShape(template: String, path: String) throws {
        let templateSegments = try HTTPPathSegment.tokenize(template: template)
        let pathSegments = HTTPPathSegment.getPathSegmentsForPath(uri: path)
        
        do {
            _ = try pathSegments.getShapeForTemplate(templateSegments: templateSegments)
            XCTFail()
        } catch {
            // expected failure
        }
    }
    
    func testBasicGetShape() throws {
        let template = "person{id}address{index}street"
        let path = "personcataddress23street"
        
        try verifySuccessfulShape(template: template, path: path)
    }
    
    func testGetShapeWithSegments() throws {
        let template = "person/{id}/address/{index}/street"
        let path = "person/cat/address/23/street"
        
        try verifySuccessfulShape(template: template, path: path)
    }
    
    func testCaseInsensitiveGetShape() throws {
        let template = "person/{id}/adDRess/{index}/street"
        let path = "Person/cat/address/23/Street"
        
        try verifySuccessfulShape(template: template, path: path)
    }
    
    func testTooFewSegmentsGetShape() throws {
        let template = "person/{id}/address/{index}/street"
        let path = "person/cat/address"

        try verifyUnsuccessfulShape(template: template, path: path)
    }
    
    func testTooManySegmentsGetShape() throws {
        let template = "person/{id}/address/{index}/street"
        let path = "person/cat/address/23/street/number/13"

        try verifyUnsuccessfulShape(template: template, path: path)
    }
    
    func testNotMatchingGetShape() throws {
        let template = "person/{id}/address/{index}/street"
        let path = "person/cat/country/23/street"

        try verifyUnsuccessfulShape(template: template, path: path)
    }
    
    func testGreedyTokenGetShape() throws {
        let template = "person/{id}/address/{index+}"
        let path = "person/cat/address/23/street"
        
        let templateSegments = try HTTPPathSegment.tokenize(template: template)
        let pathSegments = HTTPPathSegment.getPathSegmentsForPath(uri: path)
        
        let expected: [String: Shape] = ["id": .string("cat"),
                                         "index": .string("23/street")]
        
        let shape: Shape
        do {
            shape = try pathSegments.getShapeForTemplate(templateSegments: templateSegments)
        } catch {
            return XCTFail()
        }
        
        guard case let .dictionary(values) = shape else {
            return XCTFail()
        }
        
        XCTAssertEqual(expected, values)
    }
}
