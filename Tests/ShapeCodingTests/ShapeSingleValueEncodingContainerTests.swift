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
// ShapeSingleValueEncodingContainerTests.swift
// ShapeCodingTests
//

import XCTest
@testable import ShapeCoding

struct TestTypeA: Codable, Equatable {
    let firstly: String?
    let secondly: String?
    let thirdly: String?
}

struct TestTypeB: Codable, Equatable {
    let action: String
    let ids: [String]
}

struct TestTypeC: Codable, Equatable {
    let action: String
    let map: [String: String]
}

struct TestTypeD1: Codable, Equatable {
    let action: String
    let ids: [TestTypeA]
}

struct TestTypeD2: Codable, Equatable {
    let action: String
    let id: TestTypeA
}

fileprivate let useDotEncoderOptions = StandardEncodingOptions(
    shapeKeyEncodingStrategy: .useAsShapeSeparator("."),
    shapeMapEncodingStrategy: .singleShapeEntry,
    shapeKeyEncodeTransformStrategy: .none)
fileprivate let capitalizeEncoderOptions = StandardEncodingOptions(
    shapeKeyEncodingStrategy: .useAsShapeSeparator("."),
    shapeMapEncodingStrategy: .singleShapeEntry,
    shapeKeyEncodeTransformStrategy: .capitalizeFirstCharacter)
fileprivate let customTransformEncoderOptions = StandardEncodingOptions(
    shapeKeyEncodingStrategy: .useAsShapeSeparator("."),
    shapeMapEncodingStrategy: .singleShapeEntry,
    shapeKeyEncodeTransformStrategy: .custom({ key in String(key.reversed()) }))

class ShapeSingleValueEncodingContainerTests: XCTestCase {

    func encode<ValueType: Encodable>(
            value: ValueType,
            options: StandardEncodingOptions) throws -> [String: String] {
        let delegate = StandardShapeSingleValueEncodingContainerDelegate(options: options)
        let container = ShapeSingleValueEncodingContainer(
            userInfo: [:],
            codingPath: [],
            delegate: delegate,
            allowedCharacterSet: .alphanumerics,
            defaultValue: nil)
        try value.encode(to: container)

        var elements: [(String, String?)] = []
        try container.getSerializedElements(nil, isRoot: true, elements: &elements)
        
        var encodedElements: [String: String] = [:]
        elements.forEach { element in
            if let value = element.1 {
                encodedElements[element.0] = value
            }
        }
        
        return encodedElements
    }
    
    func testEncodeBasicType() throws {
        let input = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        
        let encodedValues = try encode(value: input,
                                       options: useDotEncoderOptions)
        
        let expected = [
            "firstly": "value1",
            "secondly": "value2",
            "thirdly": "value3"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeBasicTypeWithCapitialization() throws {
        let input = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        
        let encodedValues = try encode(value: input,
                                       options: capitalizeEncoderOptions)
        
        let expected = [
            "Firstly": "value1",
            "Secondly": "value2",
            "Thirdly": "value3"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeBasicTypeWithCustomTransform() throws {
        let input = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        
        let encodedValues = try encode(value: input,
                                       options: customTransformEncoderOptions)
        
        let expected = [
            "yltsrif": "value1",
            "yldnoces": "value2",
            "yldriht": "value3"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeBasicTypeWithEncoding() throws {
        let input = TestTypeA(firstly: "value1=",
                              secondly: "value2=",
                              thirdly: "value3=")
        
        let encodedValues = try encode(value: input,
                                       options: useDotEncoderOptions)
        
        let expected = [
            "firstly": "value1%3D",
            "secondly": "value2%3D",
            "thirdly": "value3%3D"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeNoValues() throws {
        let input = TestTypeA(firstly: nil,
                              secondly: nil,
                              thirdly: nil)
        
        let encodedValues = try encode(value: input,
                                       options: useDotEncoderOptions)
        
        let expected: [String: String] = [:]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithList() throws {
        let input = TestTypeB(action: "myAction", ids: ["value1", "value2"])
        
        let encodedValues = try encode(value: input,
                                       options: useDotEncoderOptions)
        
        let expected = [
            "action": "myAction",
            "ids.1": "value1",
            "ids.2": "value2"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithListWithCapitialization() throws {
        let input = TestTypeB(action: "myAction", ids: ["value1", "value2"])
        
        let encodedValues = try encode(value: input,
                                       options: capitalizeEncoderOptions)
        
        let expected = [
            "Action": "myAction",
            "Ids.1": "value1",
            "Ids.2": "value2"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithListWithCustomTransform() throws {
        let input = TestTypeB(action: "myAction", ids: ["value1", "value2"])
        
        let encodedValues = try encode(value: input,
                                       options: customTransformEncoderOptions)
        
        let expected = [
            "noitca": "myAction",
            "sdi.1": "value1",
            "sdi.2": "value2"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithMap() throws {
        let input = TestTypeC(action: "myAction",
                              map: ["id1": "value1",
                                    "id2": "value2"])
        
        let encodedValues = try encode(value: input,
                                       options: useDotEncoderOptions)
        
        let expected = [
            "action": "myAction",
            "map.id1": "value1",
            "map.id2": "value2"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithMapWithCapitialization() throws {
        let input = TestTypeC(action: "myAction",
                              map: ["id1": "value1",
                                    "id2": "value2"])
        
        let encodedValues = try encode(value: input,
                                       options: capitalizeEncoderOptions)
        
        let expected = [
            "Action": "myAction",
            "Map.Id1": "value1",
            "Map.Id2": "value2"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithMapWithCustomTransform() throws {
        let input = TestTypeC(action: "myAction",
                              map: ["id1": "value1",
                                    "id2": "value2"])
        
        let encodedValues = try encode(value: input,
                                       options: customTransformEncoderOptions)
        
        let expected = [
            "noitca": "myAction",
            "pam.1di": "value1",
            "pam.2di": "value2"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithListOfType() throws {
        let value1 = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        let value2 = TestTypeA(firstly: "value4",
                              secondly: "value5",
                              thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [value1, value2])
        
        let encodedValues = try encode(value: input,
                                       options: useDotEncoderOptions)
        
        let expected = [
            "action": "myAction",
            "ids.1.firstly": "value1",
            "ids.1.secondly": "value2",
            "ids.1.thirdly": "value3",
            "ids.2.firstly": "value4",
            "ids.2.secondly": "value5",
            "ids.2.thirdly": "value6"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithListOfTypeWithCapitialization() throws {
        let value1 = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        let value2 = TestTypeA(firstly: "value4",
                              secondly: "value5",
                              thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [value1, value2])
        
        let encodedValues = try encode(value: input,
                                       options: capitalizeEncoderOptions)
        
        let expected = [
            "Action": "myAction",
            "Ids.1.Firstly": "value1",
            "Ids.1.Secondly": "value2",
            "Ids.1.Thirdly": "value3",
            "Ids.2.Firstly": "value4",
            "Ids.2.Secondly": "value5",
            "Ids.2.Thirdly": "value6"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithListOfTypeWithCustomTransform() throws {
        let value1 = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        let value2 = TestTypeA(firstly: "value4",
                              secondly: "value5",
                              thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [value1, value2])
        
        let encodedValues = try encode(value: input,
                                       options: customTransformEncoderOptions)
        
        let expected = [
            "noitca": "myAction",
            "sdi.1.yltsrif": "value1",
            "sdi.1.yldnoces": "value2",
            "sdi.1.yldriht": "value3",
            "sdi.2.yltsrif": "value4",
            "sdi.2.yldnoces": "value5",
            "sdi.2.yldriht": "value6"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithNestedType() throws {
        let value1 = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: value1)
        
        let encodedValues = try encode(value: input,
                                       options: useDotEncoderOptions)
        
        let expected = [
            "action": "myAction",
            "id.firstly": "value1",
            "id.secondly": "value2",
            "id.thirdly": "value3"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithNestedTypeWithCapitialization() throws {
        let value1 = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: value1)
        
        let encodedValues = try encode(value: input,
                                       options: capitalizeEncoderOptions)
        
        let expected = [
            "Action": "myAction",
            "Id.Firstly": "value1",
            "Id.Secondly": "value2",
            "Id.Thirdly": "value3"]
        
        XCTAssertEqual(expected, encodedValues)
    }
    
    func testEncodeTypeWithNestedTypeWithCustomTransform() throws {
        let value1 = TestTypeA(firstly: "value1",
                              secondly: "value2",
                              thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: value1)
        
        let encodedValues = try encode(value: input,
                                       options: customTransformEncoderOptions)
        
        let expected = [
            "noitca": "myAction",
            "di.yltsrif": "value1",
            "di.yldnoces": "value2",
            "di.yldriht": "value3"]
        
        XCTAssertEqual(expected, encodedValues)
    }

    static var allTests = [
        ("testEncodeBasicType", testEncodeBasicType),
        ("testEncodeBasicTypeWithCapitialization", testEncodeBasicTypeWithCapitialization),
        ("testEncodeBasicTypeWithCustomTransform", testEncodeBasicTypeWithCustomTransform),
        ("testEncodeBasicTypeWithEncoding", testEncodeBasicTypeWithEncoding),
        ("testEncodeNoValues", testEncodeNoValues),
        ("testEncodeTypeWithList", testEncodeTypeWithList),
        ("testEncodeTypeWithListWithCapitialization", testEncodeTypeWithListWithCapitialization),
        ("testEncodeTypeWithListWithCustomTransform", testEncodeTypeWithListWithCustomTransform),
        ("testEncodeTypeWithMap", testEncodeTypeWithMap),
        ("testEncodeTypeWithMapWithCapitialization", testEncodeTypeWithMapWithCapitialization),
        ("testEncodeTypeWithMapWithCustomTransform", testEncodeTypeWithMapWithCustomTransform),
        ("testEncodeTypeWithListOfType", testEncodeTypeWithListOfType),
        ("testEncodeTypeWithListOfTypeWithCapitialization", testEncodeTypeWithListOfTypeWithCapitialization),
        ("testEncodeTypeWithListOfTypeWithCustomTransform", testEncodeTypeWithListOfTypeWithCustomTransform),
        ("testEncodeTypeWithNestedType", testEncodeTypeWithNestedType),
        ("testEncodeTypeWithNestedTypeWithCapitialization", testEncodeTypeWithNestedTypeWithCapitialization),
        ("testEncodeTypeWithNestedTypeWithCustomTransform", testEncodeTypeWithNestedTypeWithCustomTransform),
    ]
}

