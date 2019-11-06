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
//  ShapeKeyedEncodingContainer.swift
//  ShapeCoding
//

import Foundation

internal struct ShapeKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    private let enclosingContainer: ShapeSingleValueEncodingContainer

    init(enclosingContainer: ShapeSingleValueEncodingContainer) {
        self.enclosingContainer = enclosingContainer
    }

    // MARK: - Swift.KeyedEncodingContainerProtocol Methods

    var codingPath: [CodingKey] {
        return enclosingContainer.codingPath
    }

    func encodeNil(forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: "")
    }

    func encode(_ value: Bool, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: value ? "true" : "false")
    }

    func encode(_ value: Int, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: Int8, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: Int16, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: Int32, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: Int64, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: UInt, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: UInt8, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: UInt16, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: UInt32, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: UInt64, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: Float, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: Double, forKey key: Key) throws {
        enclosingContainer.addToKeyedContainer(key: key, value: String(value))
    }

    func encode(_ value: String, forKey key: Key) throws {
        let encodedValue: String
        if let allowedCharacterSet = enclosingContainer.allowedCharacterSet,
            let percentEncoded = value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                encodedValue = percentEncoded
        } else {
            encodedValue = value
        }

        enclosingContainer.addToKeyedContainer(key: key, value: encodedValue)
    }

    func encode<T>(_ value: T, forKey key: Key)   throws where T: Encodable {
        let nestedContainer = createNestedContainer(for: key)

        try nestedContainer.encode(value)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type,
                                    forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let nestedContainer = createNestedContainer(for: key, defaultValue: .keyedContainer([:]))

        let nestedKeyContainer = ShapeKeyedEncodingContainer<NestedKey>(enclosingContainer: nestedContainer)

        return KeyedEncodingContainer<NestedKey>(nestedKeyContainer)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let nestedContainer = createNestedContainer(for: key, defaultValue: .unkeyedContainer([]))

        let nestedKeyContainer = ShapeUnkeyedEncodingContainer(enclosingContainer: nestedContainer)

        return nestedKeyContainer
    }

    func superEncoder() -> Encoder { return createNestedContainer(for: ShapeCodingKey.super) }
    func superEncoder(forKey key: Key) -> Encoder { return createNestedContainer(for: key) }

    // MARK: -

    private func createNestedContainer<NestedKey: CodingKey>(for key: NestedKey,
                                                             defaultValue: ContainerValueType? = nil)
        -> ShapeSingleValueEncodingContainer {
        let nestedContainer = ShapeSingleValueEncodingContainer(
            userInfo: enclosingContainer.userInfo,
            codingPath: enclosingContainer.codingPath + [key],
            delegate: enclosingContainer.delegate,
            allowedCharacterSet: enclosingContainer.allowedCharacterSet,
            defaultValue: defaultValue)
        enclosingContainer.addToKeyedContainer(key: key, value: nestedContainer)

        return nestedContainer
    }
}
