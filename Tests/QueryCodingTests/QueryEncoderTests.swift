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
// QueryEncoderTests.swift
// QueryCoderTests
//

import XCTest
@testable import QueryCoding
import ShapeCoding

fileprivate let queryEncoder = QueryEncoder()
fileprivate let queryDecoder = QueryDecoder()

extension CharacterSet {
    public static let uriCustomQueryAllowed: CharacterSet = ["&", "\'", "(", ")", "-", ".", "0", "1", "2", "3",
                                                          "4", "5", "6", "7", "8", "9", "A", "B", "C",
                                                          "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                                                          "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W",
                                                          "X", "Y", "Z", "_", "a", "b", "c", "d", "e", "f",
                                                          "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
                                                          "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
}

class QueryEncoderTests: XCTestCase {

    func testEncodeBasicType() throws {
        let input = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")

        let query = try queryEncoder.encode(input)

        XCTAssertEqual("firstly=value1&secondly=value2&thirdly=value3", query)
        
        let decoded = try queryDecoder.decode(TestTypeA.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeBasicTypeWithEncoding() throws {
        let input = TestTypeA(firstly: "value1=", secondly: "value2=", thirdly: "value3=")

        let query = try queryEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomQueryAllowed)

        XCTAssertEqual("firstly=value1%3D&secondly=value2%3D&thirdly=value3%3D", query)
        
        let decoded = try queryDecoder.decode(TestTypeA.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeNotCompatibleType() throws {
        do {
            _ = try queryEncoder.encode("I am just a string")
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }

    func testEncodeNotCompatibleListType() throws {
        do {
            let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
            let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
            _ = try queryEncoder.encode([innerInput1, innerInput2])
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }

    func testEncodeTypeWithList() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1", "id2"])

        let query = try queryEncoder.encode(input)

        XCTAssertEqual("action=myAction&ids.1=id1&ids.2=id2", query)
        
        let decoded = try queryDecoder.decode(TestTypeB.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithListWithNoSeparator() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1", "id2"])

        let customEncoder = QueryEncoder(keyEncodingStrategy: .noSeparator)
        let query = try customEncoder.encode(input)

        XCTAssertEqual("action=myAction&ids1=id1&ids2=id2", query)
        
        let customDecoder = QueryDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeB.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithListWithEncoding() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1=", "id2="])

        let query = try queryEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomQueryAllowed)

        XCTAssertEqual("action=myAction&ids.1=id1%3D&ids.2=id2%3D", query)
        
        let decoded = try queryDecoder.decode(TestTypeB.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithMap() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1", "id2": "value2"])

        let query = try queryEncoder.encode(input)

        XCTAssertEqual("action=myAction&map.id1=value1&map.id2=value2", query)
        
        let decoded = try queryDecoder.decode(TestTypeC.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithMapWithNoSeparator() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1", "id2": "value2"])

        let customEncoder = QueryEncoder(keyEncodingStrategy: .noSeparator)
        let query = try customEncoder.encode(input)

        XCTAssertEqual("action=myAction&mapid1=value1&mapid2=value2", query)
        
        let customDecoder = QueryDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeC.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithMapWithMapEncodingStrategy() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1", "id2": "value2"])

        let mapEncodingStrategy: QueryEncoder.MapEncodingStrategy =
            .separateQueryEntriesWith(keyTag: "Name", valueTag: "Value")
        let customEncoder = QueryEncoder(mapEncodingStrategy: mapEncodingStrategy)
        let query = try customEncoder.encode(input)

        XCTAssertEqual("action=myAction&map.1.Name=id1&map.1.Value=value1&map.2.Name=id2&map.2.Value=value2", query)
        
        let mapDecodingStrategy: QueryDecoder.MapDecodingStrategy =
            .separateQueryEntriesWith(keyTag: "Name", valueTag: "Value")
        let customDecoder = QueryDecoder(mapDecodingStrategy: mapDecodingStrategy)
        
        let decoded = try customDecoder.decode(TestTypeC.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithMapWithEncoding() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1=", "id2": "value2="])

        let query = try queryEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomQueryAllowed)

        XCTAssertEqual("action=myAction&map.id1=value1%3D&map.id2=value2%3D", query)
        
        let decoded = try queryDecoder.decode(TestTypeC.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithInnerTypeList() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [innerInput1, innerInput2])

        let query = try queryEncoder.encode(input)

        XCTAssertEqual("action=myAction&ids.1.firstly=value1&ids.1.secondly=value2&ids.1.thirdly=value3"
            + "&ids.2.firstly=value4&ids.2.secondly=value5&ids.2.thirdly=value6", query)
        
        let decoded = try queryDecoder.decode(TestTypeD1.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerType() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: innerInput1)

        let query = try queryEncoder.encode(input)

        XCTAssertEqual("action=myAction&id.firstly=value1&id.secondly=value2&id.thirdly=value3", query)
        
        let decoded = try queryDecoder.decode(TestTypeD2.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerTypeListWithNoSeparator() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [innerInput1, innerInput2])

        let customEncoder = QueryEncoder(keyEncodingStrategy: .noSeparator)
        let query = try customEncoder.encode(input)

        XCTAssertEqual("action=myAction&ids1firstly=value1&ids1secondly=value2&ids1thirdly=value3"
            + "&ids2firstly=value4&ids2secondly=value5&ids2thirdly=value6", query)
        
        let customDecoder = QueryDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try! customDecoder.decode(TestTypeD1.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerTypeWithNoSeparator() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: innerInput1)

        let customEncoder = QueryEncoder(keyEncodingStrategy: .noSeparator)
        let query = try customEncoder.encode(input)

        XCTAssertEqual("action=myAction&idfirstly=value1&idsecondly=value2&idthirdly=value3", query)
        
        let customDecoder = QueryDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try! customDecoder.decode(TestTypeD2.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithInnerTypeListWithMapEncodingStrategy() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [innerInput1, innerInput2])

        let mapEncodingStrategy: QueryEncoder.MapEncodingStrategy =
            .separateQueryEntriesWith(keyTag: "Name", valueTag: "Value")
        let customEncoder = QueryEncoder(mapEncodingStrategy: mapEncodingStrategy)
        let query = try customEncoder.encode(input)

        XCTAssertEqual("action=myAction&ids.1.1.Name=firstly&ids.1.1.Value=value1&ids.1.2.Name=secondly&ids.1.2.Value=value2"
            + "&ids.1.3.Name=thirdly&ids.1.3.Value=value3&ids.2.1.Name=firstly&ids.2.1.Value=value4&ids.2.2.Name=secondly"
            + "&ids.2.2.Value=value5&ids.2.3.Name=thirdly&ids.2.3.Value=value6", query)
        
        let mapDecodingStrategy: QueryDecoder.MapDecodingStrategy =
            .separateQueryEntriesWith(keyTag: "Name", valueTag: "Value")
        let customDecoder = QueryDecoder(mapDecodingStrategy: mapDecodingStrategy)
        
        let decoded = try customDecoder.decode(TestTypeD1.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerTypeWithMapEncodingStrategy() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: innerInput1)

        let mapEncodingStrategy: QueryEncoder.MapEncodingStrategy =
            .separateQueryEntriesWith(keyTag: "Name", valueTag: "Value")
        let customEncoder = QueryEncoder(mapEncodingStrategy: mapEncodingStrategy)
        let query = try customEncoder.encode(input)

        XCTAssertEqual("action=myAction&id.1.Name=firstly&id.1.Value=value1&id.2.Name=secondly&id.2.Value=value2"
            + "&id.3.Name=thirdly&id.3.Value=value3", query)
        
        let mapDecodingStrategy: QueryDecoder.MapDecodingStrategy =
            .separateQueryEntriesWith(keyTag: "Name", valueTag: "Value")
        let customDecoder = QueryDecoder(mapDecodingStrategy: mapDecodingStrategy)
        
        let decoded = try customDecoder.decode(TestTypeD2.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    /// Test that dots in query keys don't do anything for queryKeyDecodingStrategy.flatStructure
    func testArrayLikeFlatStructure() throws {
        let input = TestTypeE(firstly: "value1", secondly: "value2", thirdly: "value3")

        let query = try queryEncoder.encode(input)

        XCTAssertEqual("values.1=value1&values.2=value2&values.3=value3", query)
        
        let customDecoder = QueryDecoder(keyDecodingStrategy: .flatStructure)
        let decoded = try customDecoder.decode(TestTypeE.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    /// Test that dots in query keys don't do anything for queryKeyDecodingStrategy.flatStructure
    func testMapLikeFlatStructure() throws {
        let input = TestTypeF(firstly: "value1", secondly: "value2", thirdly: "value3")

        let query = try queryEncoder.encode(input)

        XCTAssertEqual("values.one=value1&values.three=value3&values.two=value2", query)
        
        let customDecoder = QueryDecoder(keyDecodingStrategy: .flatStructure)
        let decoded = try customDecoder.decode(TestTypeF.self, from: query)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testDifferentAttributeTypes() throws {
        let date = Date(timeIntervalSince1970: 1534352914)
        let id = "id"
        let dataString = "<tag>value</tag>"
        let base64Data = dataString.data(using: .utf8)?.base64EncodedData()
        let boolValue = true
        let intValue = 54
        let doubleValue = 128.67
        let input = TestTypeG(id: id,
                              optionalString: nil,
                              data: base64Data,
                              date: date,
                              bool: boolValue,
                              int: 54,
                              double: 128.67)

        let query = try queryEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomQueryAllowed)

        XCTAssertEqual("Bool=true&Data=PHRhZz52YWx1ZTwvdGFnPg%3D%3D&Date=2018-08-15T17%3A08%3A34.000Z&Double=128.67&Id=id&Int=54", query)
        
        let customDecoder = QueryDecoder(keyDecodingStrategy: .flatStructure)
        let decoded = try customDecoder.decode(TestTypeG.self, from: query)
        
        XCTAssertEqual(decoded.id, id)
        XCTAssertNil(decoded.optionalString)
        XCTAssertEqual(decoded.date, date)
        XCTAssertEqual(String(data: decoded.data!, encoding: .utf8), dataString)
        XCTAssertEqual(decoded.bool, boolValue)
        XCTAssertEqual(decoded.int, intValue)
        XCTAssertEqual(String(decoded.double!), String(doubleValue))
    }

    static var allTests = [
        ("testEncodeBasicType", testEncodeBasicType),
        ("testEncodeBasicTypeWithEncoding", testEncodeBasicTypeWithEncoding),
        ("testEncodeNotCompatibleType", testEncodeNotCompatibleType),
        ("testEncodeNotCompatibleListType", testEncodeNotCompatibleListType),
        ("testEncodeTypeWithList", testEncodeTypeWithList),
        ("testEncodeTypeWithListWithNoSeparator", testEncodeTypeWithListWithNoSeparator),
        ("testEncodeTypeWithListWithEncoding", testEncodeTypeWithListWithEncoding),
        ("testEncodeTypeWithMap", testEncodeTypeWithMap),
        ("testEncodeTypeWithMapWithNoSeparator", testEncodeTypeWithMapWithNoSeparator),
        ("testEncodeTypeWithMapWithMapEncodingStrategy", testEncodeTypeWithMapWithMapEncodingStrategy),
        ("testEncodeTypeWithMapWithEncoding", testEncodeTypeWithMapWithEncoding),
        ("testEncodeTypeWithInnerTypeList", testEncodeTypeWithInnerTypeList),
        ("testEncodeTypeWithInnerType", testEncodeTypeWithInnerType),
        ("testEncodeTypeWithInnerTypeListWithNoSeparator", testEncodeTypeWithInnerTypeListWithNoSeparator),
        ("testEncodeTypeWithInnerTypeWithNoSeparator", testEncodeTypeWithInnerTypeWithNoSeparator),
        ("testEncodeTypeWithInnerTypeListWithMapEncodingStrategy", testEncodeTypeWithInnerTypeListWithMapEncodingStrategy),
        ("testEncodeTypeWithInnerTypeWithMapEncodingStrategy", testEncodeTypeWithInnerTypeWithMapEncodingStrategy),
        ("testArrayLikeFlatStructure", testArrayLikeFlatStructure),
        ("testMapLikeFlatStructure", testMapLikeFlatStructure),
    ]
}
