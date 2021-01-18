// Copyright 2018-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// HTTPPathEncoderTests.swift
// HTTPPathCodingTests
//

import XCTest
@testable import HTTPPathCoding
import ShapeCoding

fileprivate let httpPathEncoder = HTTPPathEncoder()
fileprivate let httpPathDecoder = HTTPPathDecoder()

class HTTPPathEncoderTests: XCTestCase {

    func testEncodeBasicType() throws {
        let input = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")

        let template = "items{firstly}/things/{secondly}/{thirdly}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("itemsvalue1/things/value2/value3", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeA.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeBasicTypeWithStartingSlash() throws {
        let input = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")

        let template = "/items{firstly}/things/{secondly}/{thirdly}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsvalue1/things/value2/value3", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeA.self,
                                                  from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeNotCompatibleType() throws {
        let template = "/items{firstly}/things/{secondly}/{thirdly}"
        do {
            _ = try httpPathEncoder.encode("I am just a string", withTemplate: template)
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }

    func testEncodeNotCompatibleListType() throws {
        let template = "/items{firstly}/things/{secondly}/{thirdly}"
        do {
            let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
            let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
            _ = try httpPathEncoder.encode([innerInput1, innerInput2], withTemplate: template)
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }

    func testEncodeTypeWithList() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1", "id2"])

        let template = "/items{action}/things/{ids.1}/{ids.2}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/id1/id2", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeB.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithListWithNoSeparator() throws {
        let input = TestTypeB(action: "myAction", ids: ["id1", "id2"])

        let template = "/items{action}/things/{ids1}/{ids2}"
        let customEncoder = HTTPPathEncoder(keyEncodingStrategy: .noSeparator)
        let httpPath = try customEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/id1/id2", httpPath)
        
        let customDecoder = HTTPPathDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeB.self,
                                               from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithMap() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1", "id2": "value2"])

        let template = "/items{action}/things/{map.id1}/{map.id2}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/value1/value2", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeC.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
 
    func testEncodeTypeWithMapWithNoSeparator() throws {
        let input = TestTypeC(action: "myAction", map: ["id1": "value1", "id2": "value2"])

        let template = "/items{action}/things/{mapid1}/{mapid2}"
        let customEncoder = HTTPPathEncoder(keyEncodingStrategy: .noSeparator)
        let httpPath = try customEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/value1/value2", httpPath)
        
        let customDecoder = HTTPPathDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeC.self,
                                               from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }

    func testEncodeTypeWithInnerTypeList() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [innerInput1, innerInput2])

        let template = "/items{action}/things/{ids.1.firstly}/{ids.1.secondly}/{ids.1.thirdly}/foo/{ids.2.firstly}/{ids.2.secondly}/{ids.2.thirdly}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/value1/value2/value3/foo/value4/value5/value6", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeD1.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
 
    func testEncodeTypeWithInnerType() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: innerInput1)

        let template = "/items{action}/things/{id.firstly}/{id.secondly}/{id.thirdly}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/value1/value2/value3", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeD2.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
   
    func testEncodeTypeWithInnerTypeListWithNoSeparator() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let innerInput2 = TestTypeA(firstly: "value4", secondly: "value5", thirdly: "value6")
        let input = TestTypeD1(action: "myAction", ids: [innerInput1, innerInput2])

        let template = "/items{action}/things/{ids1firstly}/{ids1secondly}/{ids1thirdly}/foo/{ids2firstly}/{ids2secondly}/{ids2thirdly}"
        let customEncoder = HTTPPathEncoder(keyEncodingStrategy: .noSeparator)
        let httpPath = try customEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/value1/value2/value3/foo/value4/value5/value6", httpPath)
        
        let customDecoder = HTTPPathDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeD1.self,
                                               from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeTypeWithInnerTypeWithNoSeparator() throws {
        let innerInput1 = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")
        let input = TestTypeD2(action: "myAction", id: innerInput1)

        let template = "/items{action}/things/{idfirstly}/{idsecondly}/{idthirdly}"
        let customEncoder = HTTPPathEncoder(keyEncodingStrategy: .noSeparator)
        let httpPath = try customEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsmyAction/things/value1/value2/value3", httpPath)
        
        let customDecoder = HTTPPathDecoder(keyDecodingStrategy: .useShapePrefix)
        let decoded = try customDecoder.decode(TestTypeD2.self,
                                               from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }

    /// Test that dots in template variables don't do anything for httpPathKeyDecodingStrategy.flatStructure
    func testArrayLikeFlatStructure() throws {
        let input = TestTypeE(firstly: "value1", secondly: "value2", thirdly: "value3")

        let template = "/items{values.1}/things/{values.2}/{values.3}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsvalue1/things/value2/value3", httpPath)
        
        let customDecoder = HTTPPathDecoder(keyDecodingStrategy: .flatStructure)
        let decoded = try customDecoder.decode(TestTypeE.self,
                                               from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
 
    /// Test that dots in template variables don't do anything for httpPathKeyDecodingStrategy.flatStructure
    func testMapLikeFlatStructure() throws {
        let input = TestTypeF(firstly: "value1", secondly: "value2", thirdly: "value3")

        let template = "/items{values.one}/things/{values.two}/{values.three}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemsvalue1/things/value2/value3", httpPath)
        
        let customDecoder = HTTPPathDecoder(keyDecodingStrategy: .flatStructure)
        let decoded = try customDecoder.decode(TestTypeF.self,
                                               from: httpPath, withTemplate: template)
        
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

        let template = "/items{Bool}/things/{Data}/{Date}/{Double}/{Id}/{Int}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("/itemstrue/things/PHRhZz52YWx1ZTwvdGFnPg==/2018-08-15T17:08:34.000Z/128.67/id/54", httpPath)
        
        let customDecoder = HTTPPathDecoder(keyDecodingStrategy: .flatStructure)
        let decoded = try customDecoder.decode(TestTypeG.self,
                                               from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded.id, id)
        XCTAssertNil(decoded.optionalString)
        XCTAssertEqual(decoded.date, date)
        XCTAssertEqual(String(data: decoded.data!, encoding: .utf8), dataString)
        XCTAssertEqual(decoded.bool, boolValue)
        XCTAssertEqual(decoded.int, intValue)
        XCTAssertEqual(String(decoded.double!), String(doubleValue))
    }
    
    func testEncodeGreedyToken() throws {
        let input = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3")

        let template = "items{firstly}/things/{secondly}/{thirdly+}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("itemsvalue1/things/value2/value3", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeA.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeGreedyMultiSegmentToken() throws {
        let input = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3/value4")

        let template = "items{firstly}/things/{secondly}/{thirdly+}"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("itemsvalue1/things/value2/value3/value4", httpPath)
        
        let decoded = try httpPathDecoder.decode(TestTypeA.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testEncodeGreedyMultiSegmentTokenWithTail() throws {
        let input = TestTypeA(firstly: "value1", secondly: "value2", thirdly: "value3/value4")

        let template = "items{firstly}/things/{secondly}/{thirdly+}?tail"
        let httpPath = try httpPathEncoder.encode(input, withTemplate: template)

        XCTAssertEqual("itemsvalue1/things/value2/value3/value4?tail", httpPath)
        
        let decoded = try! httpPathDecoder.decode(TestTypeA.self,
                                                 from: httpPath, withTemplate: template)
        
        XCTAssertEqual(decoded, input)
    }
    
    func testNonMatchingTemplate() throws {
        let template = "items{firstly}/things/{secondly}/{thirdly}"
        let httpPath = "itemsvalue1/think/value2/value3"
        
        do {
            _ = try httpPathDecoder.decode(TestTypeA.self,
                                           from: httpPath, withTemplate: template)
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }
    
    func testNonMatchingTemplate2() throws {
        let template = "items{firstly}/things/{secondly}/{thirdly}"
        let httpPath = "itemzvalue1/things/value2/value3"
        
        do {
            _ = try httpPathDecoder.decode(TestTypeA.self,
                                           from: httpPath, withTemplate: template)
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }
    
    func testNonMatchingTemplateTooFewSegments() throws {
        let template = "items{firstly}/things/{secondly}/{thirdly}"
        let httpPath = "itemzvalue1/things/value2"
        
        do {
            _ = try httpPathDecoder.decode(TestTypeA.self,
                                           from: httpPath, withTemplate: template)
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }
    
    func testNonMatchingTemplateTooManySegments() throws {
        let template = "items{firstly}/things/{secondly}/{thirdly}"
        let httpPath = "itemzvalue1/things/value2/value3/value4"
        
        do {
            _ = try httpPathDecoder.decode(TestTypeA.self,
                                           from: httpPath, withTemplate: template)
            XCTFail("Expected error not thrown")
        } catch {
            // expected error thrown
        }
    }

    static var allTests = [
        ("testEncodeBasicType", testEncodeBasicType),
        ("testEncodeBasicTypeWithStartingSlash", testEncodeBasicTypeWithStartingSlash),
        ("testEncodeNotCompatibleType", testEncodeNotCompatibleType),
        ("testEncodeNotCompatibleListType", testEncodeNotCompatibleListType),
        ("testEncodeTypeWithList", testEncodeTypeWithList),
        ("testEncodeTypeWithListWithNoSeparator", testEncodeTypeWithListWithNoSeparator),
        ("testEncodeTypeWithMap", testEncodeTypeWithMap),
        ("testEncodeTypeWithMapWithNoSeparator", testEncodeTypeWithMapWithNoSeparator),
        ("testEncodeTypeWithInnerTypeList", testEncodeTypeWithInnerTypeList),
        ("testEncodeTypeWithInnerType", testEncodeTypeWithInnerType),
        ("testEncodeTypeWithInnerTypeListWithNoSeparator", testEncodeTypeWithInnerTypeListWithNoSeparator),
        ("testEncodeTypeWithInnerTypeWithNoSeparator", testEncodeTypeWithInnerTypeWithNoSeparator),
        ("testArrayLikeFlatStructure", testArrayLikeFlatStructure),
        ("testMapLikeFlatStructure", testMapLikeFlatStructure),
        ("testEncodeGreedyToken", testEncodeGreedyToken),
        ("testEncodeGreedyMultiSegmentToken", testEncodeGreedyMultiSegmentToken),
        ("testNonMatchingTemplate", testNonMatchingTemplate),
        ("testNonMatchingTemplate2", testNonMatchingTemplate2),
        ("testNonMatchingTemplateTooFewSegments", testNonMatchingTemplateTooFewSegments),
        ("testNonMatchingTemplateTooManySegments", testNonMatchingTemplateTooManySegments),
    ]
}
