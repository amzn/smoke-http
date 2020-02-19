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
//  QueryCodingTestInput.swift
//  QueryCodingTests
//

import Foundation
@testable import QueryCoding

struct TestTypeA: Codable, Equatable {
    let firstly: String
    let secondly: String
    let thirdly: String
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

struct TestTypeE: Codable, Equatable {
    let firstly: String
    let secondly: String
    let thirdly: String
    
    enum CodingKeys: String, CodingKey {
        case firstly = "values.1"
        case secondly = "values.2"
        case thirdly = "values.3"
    }
}

struct TestTypeF: Codable, Equatable {
    let firstly: String
    let secondly: String
    let thirdly: String
    
    enum CodingKeys: String, CodingKey {
        case firstly = "values.one"
        case secondly = "values.two"
        case thirdly = "values.three"
    }
}

struct TestTypeG: Codable, Equatable {
    let id: String
    let optionalString: String?
    let data: Data?
    let date: Date?
    let bool: Bool?
    let int: Int?
    let double: Double?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case optionalString = "OptionalString"
        case data = "Data"
        case date = "Date"
        case bool = "Bool"
        case int = "Int"
        case double = "Double"
    }
}
