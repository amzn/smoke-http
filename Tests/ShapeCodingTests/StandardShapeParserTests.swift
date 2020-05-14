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
// StandardShapeParserTests.swift
// ShapeCodingTests
//

import XCTest
@testable import ShapeCoding

fileprivate let useDotDecoderOptions = StandardDecodingOptions(
    shapeKeyDecodingStrategy: .useAsShapeSeparator("."),
    shapeMapDecodingStrategy: .singleShapeEntry,
    shapeListDecodingStrategy: .collapseListWithIndex,
    shapeKeyDecodeTransformStrategy: .none)
fileprivate let uncapitalizeDecoderOptions = StandardDecodingOptions(
    shapeKeyDecodingStrategy: .useAsShapeSeparator("."),
    shapeMapDecodingStrategy: .singleShapeEntry,
    shapeListDecodingStrategy: .collapseListWithIndex,
    shapeKeyDecodeTransformStrategy: .uncapitalizeFirstCharacter)
fileprivate let customTransformDecoderOptions = StandardDecodingOptions(
    shapeKeyDecodingStrategy: .useAsShapeSeparator("."),
    shapeMapDecodingStrategy: .singleShapeEntry,
    shapeListDecodingStrategy: .collapseListWithIndex,
    shapeKeyDecodeTransformStrategy: .custom({ key in String(key.reversed()) }))
fileprivate let flatStructureDecoderOptions = StandardDecodingOptions(
    shapeKeyDecodingStrategy: .flatStructure,
    shapeMapDecodingStrategy: .singleShapeEntry,
    shapeListDecodingStrategy: .collapseListWithIndex,
    shapeKeyDecodeTransformStrategy: .none)

class StandardShapeParserTests: XCTestCase {

    func testDecodeBasicType() throws {
        let input: [(String, String?)] = [("Firstly", "value1"),
                                          ("Secondly", "value2"),
                                          ("Thirdly", "value3")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: useDotDecoderOptions)
        
        let expected = Shape.dictionary([
            "Firstly": .string("value1"),
            "Secondly": .string("value2"),
            "Thirdly": .string("value3")])
        
        XCTAssertEqual(expected, shape)
    }
    
    func testDecodeBasicTypeWithUncapitalization() throws {
        let input: [(String, String?)] = [("Firstly", "value1"),
                                          ("Secondly", "value2"),
                                          ("Thirdly", "value3")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: uncapitalizeDecoderOptions)
        
        let expected = Shape.dictionary([
            "firstly": .string("value1"),
            "secondly": .string("value2"),
            "thirdly": .string("value3")])
        
        XCTAssertEqual(expected, shape)
    }
    
    func testDecodeBasicTypeWithCustomTransform() throws {
        let input: [(String, String?)] = [("Firstly", "value1"),
                                          ("Secondly", "value2"),
                                          ("Thirdly", "value3")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: customTransformDecoderOptions)
        
        let expected = Shape.dictionary([
            "yltsriF": .string("value1"),
            "yldnoceS": .string("value2"),
            "yldrihT": .string("value3")])
        
        XCTAssertEqual(expected, shape)
    }

    func testDecodeBasicTypeWithEncoding() throws {
        let input: [(String, String?)] = [("Firstly", "value1%3D"),
                                          ("Secondly", "value2%3D"),
                                          ("Thirdly", "value3%3D")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: useDotDecoderOptions)
        
        let expected = Shape.dictionary([
            "Firstly": .string("value1="),
            "Secondly": .string("value2="),
            "Thirdly": .string("value3=")])
        
        XCTAssertEqual(expected, shape)
    }

    func testDecodeNoValues() throws {
        let input: [(String, String?)] = [("Firstly", nil),
                                          ("Secondly", nil),
                                          ("Thirdly", nil)]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: useDotDecoderOptions)
    
        let expected = Shape.dictionary([
            "Firstly": .null,
            "Secondly": .null,
            "Thirdly": .null])
    
        XCTAssertEqual(expected, shape)
    }

    func testDecodeTypeWithMap() throws {
        let input: [(String, String?)] = [("Action", "myAction"),
                                          ("Map.Id1", "value1"),
                                          ("Map.Id2", "value2")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: useDotDecoderOptions)
        
        let expected = Shape.dictionary([
            "Action": .string("myAction"),
            "Map": .dictionary(["Id1": .string("value1"),
                                "Id2": .string("value2")])])
        
        XCTAssertEqual(expected, shape)
    }
    
    func testDecodeTypeWithMapWithUncapitalization() throws {
        let input: [(String, String?)] = [("Action", "myAction"),
                                          ("Map.Id1", "value1"),
                                          ("Map.Id2", "value2")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: uncapitalizeDecoderOptions)
        
        let expected = Shape.dictionary([
            "action": .string("myAction"),
            "map": .dictionary(["id1": .string("value1"),
                                "id2": .string("value2")])])
        
        XCTAssertEqual(expected, shape)
    }
    
    func testDecodeTypeWithMapWithCustomTransform() throws {
        let input: [(String, String?)] = [("Action", "myAction"),
                                          ("Map.Id1", "value1"),
                                          ("Map.Id2", "value2")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: customTransformDecoderOptions)
        
        let expected = Shape.dictionary([
            "noitcA": .string("myAction"),
            "paM": .dictionary(["1dI": .string("value1"),
                                "2dI": .string("value2")])])
        
        XCTAssertEqual(expected, shape)
    }
    
    func testDecodeTypeWithMapLikeFlatStructure() throws {
        let input: [(String, String?)] = [("Action", "myAction"),
                                          ("Map.Id1", "value1"),
                                          ("Map.Id2", "value2")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: flatStructureDecoderOptions)
        
        let expected = Shape.dictionary([
            "Action": .string("myAction"),
            "Map.Id1": .string("value1"),
            "Map.Id2": .string("value2")])
        
        XCTAssertEqual(expected, shape)
    }

    func testDecodeTypeWithMapWithMapDecodingStrategy() throws {
        let input: [(String, String?)] = [("Action", "myAction"),
                                          ("Map.1.Name", "id1"),
                                          ("Map.1.Value", "value1"),
                                          ("Map.2.Name", "id2"),
                                          ("Map.2.Value", "value2")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: useDotDecoderOptions)
        
        let expected = Shape.dictionary([
            "Action": .string("myAction"),
            "Map": .dictionary(["1": .dictionary(["Name": .string("id1"),
                                                  "Value": .string("value1")]),
                                "2": .dictionary(["Name": .string("id2"),
                                                  "Value": .string("value2")])])])
        
        XCTAssertEqual(expected, shape)
    }
    
    func testDecodeTypeWithMapWithMapDecodingStrategyWithUncapitialization() throws {
        let input: [(String, String?)] = [("Action", "myAction"),
                                          ("Map.1.Name", "id1"),
                                          ("Map.1.Value", "value1"),
                                          ("Map.2.Name", "id2"),
                                          ("Map.2.Value", "value2")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: uncapitalizeDecoderOptions)
        
        let expected = Shape.dictionary([
            "action": .string("myAction"),
            "map": .dictionary(["1": .dictionary(["name": .string("id1"),
                                                  "value": .string("value1")]),
                                "2": .dictionary(["name": .string("id2"),
                                                  "value": .string("value2")])])])
        
        XCTAssertEqual(expected, shape)
    }
    
    func testDecodeTypeWithMapWithMapDecodingStrategyWithCustomTransform() throws {
        let input: [(String, String?)] = [("Action", "myAction"),
                                          ("Map.1.Name", "id1"),
                                          ("Map.1.Value", "value1"),
                                          ("Map.2.Name", "id2"),
                                          ("Map.2.Value", "value2")]
        let shape = try StandardShapeParser.parse(with: input,
                                                  decoderOptions: customTransformDecoderOptions)
        
        let expected = Shape.dictionary([
            "noitcA": .string("myAction"),
            "paM": .dictionary(["1": .dictionary(["emaN": .string("id1"),
                                                  "eulaV": .string("value1")]),
                                "2": .dictionary(["emaN": .string("id2"),
                                                  "eulaV": .string("value2")])])])
        
        XCTAssertEqual(expected, shape)
    }

    func testDecodeTypeWithMapWithEncoding() throws {
        let input: [(String, String?)] = [("action", "myAction"),
                                          ("map.id1", "value1%3D"),
                                          ("map.id2", "value2%3D")]
        let shape = try StandardShapeParser.parse(with: input,
                                                      decoderOptions: useDotDecoderOptions)
        
        let expected = Shape.dictionary([
            "action": .string("myAction"),
            "map": .dictionary(["id1": .string("value1="),
                                "id2": .string("value2=")])])
        
        XCTAssertEqual(expected, shape)
    }

    static var allTests = [
        ("testDecodeBasicType", testDecodeBasicType),
        ("testDecodeBasicTypeWithUncapitalization", testDecodeBasicTypeWithUncapitalization),
        ("testDecodeBasicTypeWithCustomTransform", testDecodeBasicTypeWithCustomTransform),
        ("testDecodeBasicTypeWithEncoding", testDecodeBasicTypeWithEncoding),
        ("testDecodeNoValues", testDecodeNoValues),
        ("testDecodeTypeWithMap", testDecodeTypeWithMap),
        ("testDecodeTypeWithMapWithUncapitalization", testDecodeTypeWithMapWithUncapitalization),
        ("testDecodeTypeWithMapWithCustomTransform", testDecodeTypeWithMapWithCustomTransform),
        ("testDecodeTypeWithMapLikeFlatStructure", testDecodeTypeWithMapLikeFlatStructure),
        ("testDecodeTypeWithMapWithMapDecodingStrategy", testDecodeTypeWithMapWithMapDecodingStrategy),
        ("testDecodeTypeWithMapWithMapDecodingStrategyWithUncapitialization",
         testDecodeTypeWithMapWithMapDecodingStrategyWithUncapitialization),
        ("testDecodeTypeWithMapWithMapDecodingStrategyWithCustomTransform", testDecodeTypeWithMapWithMapDecodingStrategyWithCustomTransform),
        ("testDecodeTypeWithMapWithEncoding", testDecodeTypeWithMapWithEncoding),
    ]
}
