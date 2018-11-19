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
// StandardShapeParserTests.swift
// ShapeCodingTests
//

import XCTest
@testable import ShapeCoding

fileprivate let useDotDecoderOptions = StandardDecodingOptions(
    stackKeyDecodingStrategy: .useAsShapeSeparator("."),
    stackMapDecodingStrategy: .singleShapeEntry)
fileprivate let flatStructureDecoderOptions = StandardDecodingOptions(
    stackKeyDecodingStrategy: .flatStructure,
    stackMapDecodingStrategy: .singleShapeEntry)

class StandardShapeParserTests: XCTestCase {

    func testEncodeBasicType() throws {
        let input: [(String, String?)] = [("firstly", "value1"),
                                          ("secondly", "value2"),
                                          ("thirdly", "value3")]
        let stackValue = try StandardShapeParser.parse(with: input,
                                                       decoderOptions: useDotDecoderOptions)
        
        let expected = ShapeAttribute.dictionary([
            "firstly": .string("value1"),
            "secondly": .string("value2"),
            "thirdly": .string("value3")])
        
        XCTAssertEqual(expected, stackValue)
    }

    func testEncodeBasicTypeWithEncoding() throws {
        let input: [(String, String?)] = [("firstly", "value1%3D"),
                                          ("secondly", "value2%3D"),
                                          ("thirdly", "value3%3D")]
        let stackValue = try StandardShapeParser.parse(with: input,
                                                          decoderOptions: useDotDecoderOptions)
        
        let expected = ShapeAttribute.dictionary([
            "firstly": .string("value1="),
            "secondly": .string("value2="),
            "thirdly": .string("value3=")])
        
        XCTAssertEqual(expected, stackValue)
    }

    func testEncodeNoValues() throws {
        let input: [(String, String?)] = [("firstly", nil),
                                          ("secondly", nil),
                                          ("thirdly", nil)]
        let stackValue = try StandardShapeParser.parse(with: input,
                                                      decoderOptions: useDotDecoderOptions)
    
        let expected = ShapeAttribute.dictionary([
            "firstly": .null,
            "secondly": .null,
            "thirdly": .null])
    
        XCTAssertEqual(expected, stackValue)
    }

    func testEncodeTypeWithMap() throws {
        let input: [(String, String?)] = [("action", "myAction"),
                                          ("map.id1", "value1"),
                                          ("map.id2", "value2")]
        let stackValue = try StandardShapeParser.parse(with: input,
                                                      decoderOptions: useDotDecoderOptions)
        
        let expected = ShapeAttribute.dictionary([
            "action": .string("myAction"),
            "map": .dictionary(["id1": .string("value1"),
                                "id2": .string("value2")])])
        
        XCTAssertEqual(expected, stackValue)
    }
    
    func testEncodeTypeWithMapLikeFlatStructure() throws {
        let input: [(String, String?)] = [("action", "myAction"),
                                          ("map.id1", "value1"),
                                          ("map.id2", "value2")]
        let stackValue = try StandardShapeParser.parse(with: input,
                                                      decoderOptions: flatStructureDecoderOptions)
        
        let expected = ShapeAttribute.dictionary([
            "action": .string("myAction"),
            "map.id1": .string("value1"),
            "map.id2": .string("value2")])
        
        XCTAssertEqual(expected, stackValue)
    }

    func testEncodeTypeWithMapWithMapDecodingStrategy() throws {
        let input: [(String, String?)] = [("action", "myAction"),
                                          ("map.1.Name", "id1"),
                                          ("map.1.Value", "value1"),
                                          ("map.2.Name", "id2"),
                                          ("map.2.Value", "value2")]
        let stackValue = try StandardShapeParser.parse(with: input,
                                                      decoderOptions: useDotDecoderOptions)
        
        let expected = ShapeAttribute.dictionary([
            "action": .string("myAction"),
            "map": .dictionary(["1": .dictionary(["Name": .string("id1"),
                                                  "Value": .string("value1")]),
                                "2": .dictionary(["Name": .string("id2"),
                                                  "Value": .string("value2")])])])
        
        XCTAssertEqual(expected, stackValue)
    }

    func testEncodeTypeWithMapWithEncoding() throws {
        let input: [(String, String?)] = [("action", "myAction"),
                                          ("map.id1", "value1%3D"),
                                          ("map.id2", "value2%3D")]
        let stackValue = try StandardShapeParser.parse(with: input,
                                                      decoderOptions: useDotDecoderOptions)
        
        let expected = ShapeAttribute.dictionary([
            "action": .string("myAction"),
            "map": .dictionary(["id1": .string("value1="),
                                "id2": .string("value2=")])])
        
        XCTAssertEqual(expected, stackValue)
    }

    static var allTests = [
        ("testEncodeBasicType", testEncodeBasicType),
        ("testEncodeBasicTypeWithEncoding", testEncodeBasicTypeWithEncoding),
        ("testEncodeNoValues", testEncodeNoValues),
        ("testEncodeTypeWithMap", testEncodeTypeWithMap),
        ("testEncodeTypeWithMapLikeFlatStructure", testEncodeTypeWithMapLikeFlatStructure),
        ("testEncodeTypeWithMapWithMapDecodingStrategy", testEncodeTypeWithMapWithMapDecodingStrategy),
        ("testEncodeTypeWithMapWithEncoding", testEncodeTypeWithMapWithEncoding),
    ]
}
