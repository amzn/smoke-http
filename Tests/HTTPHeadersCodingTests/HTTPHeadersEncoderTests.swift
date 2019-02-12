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
// HTTPHeadersEncoderTests.swift
// HTTPHeadersCodingTests
//

import XCTest
@testable import HTTPHeadersCoding
import ShapeCoding

fileprivate let httpHeadersEncoder = HTTPHeadersEncoder()
fileprivate let httpHeadersDecoder = HTTPHeadersDecoder()

extension CharacterSet {
    public static let uriCustomHeadersAllowed: CharacterSet = ["&", "\'", "(", ")", "-", ".", "0", "1", "2", "3",
                                                          "4", "5", "6", "7", "8", "9", "A", "B", "C",
                                                          "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                                                          "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W",
                                                          "X", "Y", "Z", "_", "a", "b", "c", "d", "e", "f",
                                                          "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
                                                          "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
}

class HTTPHeadersEncoderTests: XCTestCase {
    
    func serializeHeaders(_ headers: [(String, String?)]) -> String {
        return headers.map { (key, value) in
            if let theString = value {
                return "\(key)=\(theString)"
            } else {
                return key
            }
        }.joined(separator: "|")
    }

    func testEncodeBasicType() throws {
        let input = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")

        let headers = try httpHeadersEncoder.encode(input)

        let expected: [(String, String?)] = [("firstly", "value1"),
                                                       ("secondly", "value2"),
                                                       ("thirdly", "value3")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let decoded = try httpHeadersDecoder.decode(TestTypeA.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeBasicTypeWithEncoding() throws {
        let input = TestTypeA(firstly: "value1=", secondly: "value2=", thirdly: "value3=")

        let headers = try httpHeadersEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomHeadersAllowed)

        let expected: [(String, String?)] = [("firstly", "value1%3D"),
                                             ("secondly", "value2%3D"),
                                             ("thirdly", "value3%3D")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let decoded = try httpHeadersDecoder.decode(TestTypeA.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeNotCompatibleType() throws {
        do {
            _ = try httpHeadersEncoder.encode("I am just a string")
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }

    func testEncodeNotCompatibleListType() throws {
        do {
            let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
            let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
            _ = try httpHeadersEncoder.encode([innerInput1, innerInput2])
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }

    func testEncodeTypeWithList() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1", "id2"])

        let headers = try httpHeadersEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("ids-1", "id1"),
                                             ("ids-2", "id2")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let decoded = try httpHeadersDecoder.decode(TestTypeB.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithListWithNoSeparator() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1", "id2"])

        let customEncoder = HTTPHeadersEncoder(keyEncodingStrategy: .noSeparator)
        let headers = try customEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("ids1", "id1"),
                                             ("ids2", "id2")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let customDecoder = HTTPHeadersDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeB.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithListWithEncoding() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1=", "id2="])

        let headers = try httpHeadersEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomHeadersAllowed)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("ids-1", "id1%3D"),
                                             ("ids-2", "id2%3D")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let decoded = try httpHeadersDecoder.decode(TestTypeB.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithMap() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1", "id2": "value2"])

        let headers = try httpHeadersEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("map-id1", "value1"),
                                             ("map-id2", "value2")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let decoded = try httpHeadersDecoder.decode(TestTypeC.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithMapWithNoSeparator() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1", "id2": "value2"])

        let customEncoder = HTTPHeadersEncoder(keyEncodingStrategy: .noSeparator)
        let headers = try customEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("mapid1", "value1"),
                                             ("mapid2", "value2")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let customDecoder = HTTPHeadersDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeC.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithMapWithEncoding() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1=", "id2": "value2="])

        let headers = try httpHeadersEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomHeadersAllowed)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("map-id1", "value1%3D"),
                                             ("map-id2", "value2%3D")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let decoded = try httpHeadersDecoder.decode(TestTypeC.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithInnerTypeList() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [innerInput1, innerInput2])

        let headers = try httpHeadersEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("ids-1-firstly", "value1"),
                                             ("ids-1-secondly", "value2"),
                                             ("ids-1-thirdly", "value3"),
                                             ("ids-2-firstly", "value4"),
                                             ("ids-2-secondly", "value5"),
                                             ("ids-2-thirdly", "value6")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))

        let decoded = try httpHeadersDecoder.decode(TestTypeD1.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerTypeListWithNoSeparator() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [innerInput1, innerInput2])

        let customEncoder = HTTPHeadersEncoder(keyEncodingStrategy: .noSeparator)
        let headers = try customEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("ids1firstly", "value1"),
                                             ("ids1secondly", "value2"),
                                             ("ids1thirdly", "value3"),
                                             ("ids2firstly", "value4"),
                                             ("ids2secondly", "value5"),
                                             ("ids2thirdly", "value6")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))

        let customDecoder = HTTPHeadersDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeD1.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerType() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: innerInput1)

        let headers = try httpHeadersEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("id-firstly", "value1"),
                                             ("id-secondly", "value2"),
                                             ("id-thirdly", "value3")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))

        let decoded = try httpHeadersDecoder.decode(TestTypeD2.self, from: headers)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerTypeWithNoSeparator() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: innerInput1)

        let customEncoder = HTTPHeadersEncoder(keyEncodingStrategy: .noSeparator)
        let headers = try customEncoder.encode(input)
        
        let expected: [(String, String?)] = [("action", "myAction"),
                                             ("idfirstly", "value1"),
                                             ("idsecondly", "value2"),
                                             ("idthirdly", "value3")]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))

        let customDecoder = HTTPHeadersDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeD2.self, from: headers)
        
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
                              int: intValue,
                              double: doubleValue)

        let headers = try httpHeadersEncoder.encode(input,
                                            allowedCharacterSet: .uriCustomHeadersAllowed)

       let expected: [(String, String?)] = [("Bool", "true"),
                                             ("Data", "PHRhZz52YWx1ZTwvdGFnPg%3D%3D"),
                                             ("Date", "2018-08-15T17%3A08%3A34.000Z"),
                                             ("Double", String(doubleValue)),
                                             ("Id", "id"),
                                             ("Int", String(intValue))]
        
        XCTAssertEqual(serializeHeaders(expected), serializeHeaders(headers))
        
        let customDecoder = HTTPHeadersDecoder(keyDecodingStrategy: .flatStructure)
        let decoded = try customDecoder.decode(TestTypeG.self, from: headers)
        
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
        ("testEncodeTypeWithMapWithEncoding", testEncodeTypeWithMapWithEncoding),
        ("testEncodeTypeWithInnerTypeList", testEncodeTypeWithInnerTypeList),
        ("testEncodeTypeWithInnerType", testEncodeTypeWithInnerType),
        ("testEncodeTypeWithInnerTypeListWithNoSeparator", testEncodeTypeWithInnerTypeListWithNoSeparator),
        ("testEncodeTypeWithInnerTypeWithNoSeparator", testEncodeTypeWithInnerTypeWithNoSeparator),
    ]
}
