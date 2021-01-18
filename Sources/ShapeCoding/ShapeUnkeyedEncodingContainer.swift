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
//  ShapeUnkeyedEncodingContainer.swift
//  ShapeCoding
//

import Foundation

internal struct ShapeUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let enclosingContainer: ShapeSingleValueEncodingContainer

    init(enclosingContainer: ShapeSingleValueEncodingContainer) {
        self.enclosingContainer = enclosingContainer
    }

    // MARK: - Swift.UnkeyedEncodingContainer Methods

    var codingPath: [CodingKey] {
        return enclosingContainer.codingPath
    }

    var count: Int { return enclosingContainer.unkeyedContainerCount }

    func encodeNil() throws {
        enclosingContainer.addToUnkeyedContainer(value: "") }

    func encode(_ value: Bool) throws {
        enclosingContainer.addToUnkeyedContainer(value: value ? "true" : "false") }

    func encode(_ value: Int) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: Int8) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: Int16) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: Int32) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: Int64) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: UInt) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: UInt8) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: UInt16) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: UInt32) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: UInt64) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: Float) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: Double) throws {
        enclosingContainer.addToUnkeyedContainer(value: String(value))
    }

    func encode(_ value: String) throws {
        let encodedValue: String
        if let allowedCharacterSet = enclosingContainer.allowedCharacterSet,
            let percentEncoded = value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                encodedValue = percentEncoded
        } else {
            encodedValue = value
        }

        enclosingContainer.addToUnkeyedContainer(value: encodedValue)
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        try createNestedContainer().encode(value)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let nestedContainer = createNestedContainer(defaultValue: .keyedContainer([:]))

        let nestedKeyContainer = ShapeKeyedEncodingContainer<NestedKey>(enclosingContainer: nestedContainer)

        return KeyedEncodingContainer<NestedKey>(nestedKeyContainer)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedContainer = createNestedContainer(defaultValue: .unkeyedContainer([]))

        let nestedKeyContainer = ShapeUnkeyedEncodingContainer(enclosingContainer: nestedContainer)

        return nestedKeyContainer
    }

    func superEncoder() -> Encoder { return createNestedContainer() }

    // MARK: -

    private func createNestedContainer(defaultValue: ContainerValueType? = nil)
        -> ShapeSingleValueEncodingContainer {
        let index = enclosingContainer.unkeyedContainerCount

        let nestedContainer = ShapeSingleValueEncodingContainer(
            userInfo: enclosingContainer.userInfo,
            codingPath: enclosingContainer.codingPath + [ShapeCodingKey(index: index)],
            delegate: enclosingContainer.delegate,
            allowedCharacterSet: enclosingContainer.allowedCharacterSet,
            defaultValue: defaultValue)
        enclosingContainer.addToUnkeyedContainer(value: nestedContainer)

        return nestedContainer
    }
}
