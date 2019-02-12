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
//  HTTPPathTokenTests.swift
//  HTTPPathCodingTests
//

import XCTest
@testable import HTTPPathCoding

class HTTPPathTokenTests: XCTestCase {

    func testBasicTokenize() throws {
        let input = "person{id}address{index}street"

        let expected: [HTTPPathToken] = [.string("person"),
                                         .variable(name: "id", multiSegment: false),
                                         .string("address"),
                                         .variable(name: "index", multiSegment: false),
                                         .string("street")]
        
        let output = try HTTPPathToken.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeAtStart() throws {
        let input = "{id}address{index}street"

        let expected: [HTTPPathToken] = [.variable(name: "id", multiSegment: false),
                                         .string("address"),
                                         .variable(name: "index", multiSegment: false),
                                         .string("street")]
        
        let output = try HTTPPathToken.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeAtEnd() throws {
        let input = "person{id}address{index}"

        let expected: [HTTPPathToken] = [.string("person"),
                                         .variable(name: "id", multiSegment: false),
                                         .string("address"),
                                         .variable(name: "index", multiSegment: false)]
        
        let output = try HTTPPathToken.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeAtEndWithPlus() throws {
        let input = "/person/{id}/address/{path+}"

        let expected: [HTTPPathToken] = [.string("/person/"),
                                         .variable(name: "id", multiSegment: false),
                                         .string("/address/"),
                                         .variable(name: "path", multiSegment: true)]
        
        let output = try HTTPPathToken.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testInvalidTokenize() throws {
        let input = "person{id+}address{index}"
        
        do {
            _ = try HTTPPathToken.tokenize(template: input)
            XCTFail()
        } catch {
            // expected
        }
    }
    
    func testInvalidAdjoiningVariables() throws {
        let input = "person{id}{count}address{index}"
        
        do {
            _ = try HTTPPathToken.tokenize(template: input)
            XCTFail()
        } catch {
            // expected
        }
    }

    static var allTests = [
        ("testBasicTokenize", testBasicTokenize),
        ("testTokenizeAtStart", testTokenizeAtStart),
        ("testTokenizeAtEnd", testTokenizeAtEnd),
        ("testTokenizeAtEndWithPlus", testTokenizeAtEndWithPlus),
        ("testInvalidTokenize", testInvalidTokenize),
    ]
}
