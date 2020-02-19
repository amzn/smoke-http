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
//  HTTPPathTokenTests.swift
//  HTTPPathCodingTests
//

import XCTest
@testable import HTTPPathCoding

class HTTPPathSegmentTests: XCTestCase {

    func testBasicTokenize() throws {
        let input = "person/{id}/address{index}/street"

        let expected = [HTTPPathSegment(tokens: [.string("person")]),
                        HTTPPathSegment(tokens: [.variable(name: "id", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("address"),
                                         .variable(name: "index", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("street")])]
        
        let output = try HTTPPathSegment.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeStartingSlash() throws {
        let input = "/person/{id}/address{index}/street"

        let expected = [HTTPPathSegment(tokens: [.string("person")]),
                        HTTPPathSegment(tokens: [.variable(name: "id", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("address"),
                                         .variable(name: "index", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("street")])]
        
        let output = try HTTPPathSegment.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeAtStart() throws {
        let input = "{id}/address{index}/street"

        let expected = [HTTPPathSegment(tokens: [.variable(name: "id", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("address"),
                                         .variable(name: "index", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("street")])]
        
        let output = try HTTPPathSegment.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeAtEnd() throws {
        let input = "/person/{id}/address{index}"

        let expected = [HTTPPathSegment(tokens: [.string("person")]),
                        HTTPPathSegment(tokens: [.variable(name: "id", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("address"),
                                         .variable(name: "index", multiSegment: false)])]
        
        let output = try HTTPPathSegment.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeAtEndWithPlus() throws {
        let input = "/person/{id}/address{index+}"

        let expected = [HTTPPathSegment(tokens: [.string("person")]),
                        HTTPPathSegment(tokens: [.variable(name: "id", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("address"),
                                         .variable(name: "index", multiSegment: true)])]
        
        let output = try HTTPPathSegment.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testTokenizeAtEndWithPlusWithTrail() throws {
        let input = "/person/{id}/address{index+}?trail"

        let expected = [HTTPPathSegment(tokens: [.string("person")]),
                        HTTPPathSegment(tokens: [.variable(name: "id", multiSegment: false)]),
                        HTTPPathSegment(tokens: [.string("address"),
                                         .variable(name: "index", multiSegment: true),
                                         .string("?trail")])]
        
        let output = try! HTTPPathSegment.tokenize(template: input)
        XCTAssertEqual(expected, output)
    }
    
    func testInvalidTokenize() throws {
        let input = "/person/{id+}/address{index}"
        
        do {
            _ = try HTTPPathSegment.tokenize(template: input)
            
            XCTFail()
        } catch {
            // expected
        }
    }
    
    func testInvalidTokenizeWithTrail() throws {
        let input = "/person/{id+}trail/address{index}"
        
        do {
            _ = try HTTPPathSegment.tokenize(template: input)
            
            XCTFail()
        } catch {
            // expected
        }
    }

    static var allTests = [
        ("testBasicTokenize", testBasicTokenize),
        ("testTokenizeStartingSlash", testTokenizeStartingSlash),
        ("testTokenizeAtStart", testTokenizeAtStart),
        ("testTokenizeAtEnd", testTokenizeAtEnd),
        ("testTokenizeAtEndWithPlus", testTokenizeAtEndWithPlus),
        ("testTokenizeAtEndWithPlusWithTrail", testTokenizeAtEndWithPlusWithTrail),
        ("testInvalidTokenize", testInvalidTokenize),
        ("testInvalidTokenizeWithTrail", testInvalidTokenizeWithTrail),
    ]
}
