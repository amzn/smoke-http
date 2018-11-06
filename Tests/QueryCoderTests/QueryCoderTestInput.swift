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
//  QueryCoderTestInput.swift
//  QueryCoderTests
//

import Foundation
@testable import QueryCoder

struct TestTypeA: Codable {
    let firstly: String
    let secondly: String
    let thirdly: String
}

struct TestTypeB: Codable {
    let action: String
    let ids: [String]
}

struct TestTypeC: Codable {
    let action: String
    let map: [String: String]
}

struct TestTypeD: Codable {
    let action: String
    let ids: [TestTypeA]
}
