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
//  ShapeSingleValueEncodingContainer.swift
//  ShapeCoding
//

import Foundation

/**
 Conforms to the SingleValueEncodingContainer protocol to manage encoding a
 value into shape elements.
 */
public class ShapeSingleValueEncodingContainer: SingleValueEncodingContainer {
    internal var containerValue: ContainerValueType?

    public let codingPath: [CodingKey]
    let allowedCharacterSet: CharacterSet?
    public let userInfo: [CodingUserInfoKey: Any]
    let delegate: ShapeSingleValueEncodingContainerDelegate

    public init(userInfo: [CodingUserInfoKey: Any],
                codingPath: [CodingKey],
                delegate: ShapeSingleValueEncodingContainerDelegate,
                allowedCharacterSet: CharacterSet?,
                defaultValue: ContainerValueType?) {
        self.containerValue = defaultValue
        self.userInfo = userInfo
        self.allowedCharacterSet = allowedCharacterSet
        self.codingPath = codingPath
        self.delegate = delegate
    }

    public func encodeNil() throws {
        containerValue = .singleValue("")
    }

    public func encode(_ value: Bool) throws {
        containerValue = .singleValue(value ? "true" : "false")
    }

    public func encode(_ value: Int) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: Int8) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: Int16) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: Int32) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: Int64) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: UInt) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: UInt8) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: UInt16) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: UInt32) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: UInt64) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: Float) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: Double) throws {
        containerValue = .singleValue(String(value))
    }

    public func encode(_ value: String) throws {
        let encodedValue: String
        if let allowedCharacterSet = allowedCharacterSet,
            let percentEncoded = value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                encodedValue = percentEncoded
        } else {
            encodedValue = value
        }

        containerValue = .singleValue(encodedValue)
    }

    public func encode<T>(_ value: T) throws where T: Encodable {
        if let date = value as? Foundation.Date {
            let dateAsString = date.iso8601
            
            let encodedValue: String
            if let allowedCharacterSet = allowedCharacterSet,
                let percentEncoded = dateAsString.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                    encodedValue = percentEncoded
            } else {
                encodedValue = dateAsString
            }

            containerValue = .singleValue(encodedValue)
            return
        } else if let data = value as? Foundation.Data {
            guard let dataAsString = String(data: data, encoding: .utf8) else {
                let description = "Unable to serialize data instance."
                throw EncodingError.invalidValue(data, EncodingError.Context(codingPath: self.codingPath,
                                                                             debugDescription: description))
            }
            
            let encodedValue: String
            if let allowedCharacterSet = allowedCharacterSet,
                let percentEncoded = dataAsString.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                    encodedValue = percentEncoded
            } else {
                encodedValue = dataAsString
            }

            containerValue = .singleValue(encodedValue)
            return
        }

        try value.encode(to: self)
    }

    func addToKeyedContainer<KeyType: CodingKey>(key: KeyType, value: ShapeElement) {
        guard let currentContainerValue = containerValue else {
            fatalError("Attempted to add a keyed item to an unitinialized container.")
        }

        guard case .keyedContainer(var values) = currentContainerValue else {
            fatalError("Expected keyed container and there wasn't one.")
        }

        let attributeName = key.stringValue

        values[attributeName] = value

        containerValue = .keyedContainer(values)
    }

    func addToUnkeyedContainer(value: ShapeElement) {
        guard let currentContainerValue = containerValue else {
            fatalError("Attempted to ad an unkeyed item to an uninitialized container.")
        }

        guard case .unkeyedContainer(var values) = currentContainerValue else {
            fatalError("Expected unkeyed container and there wasn't one.")
        }

        values.append(value)

        containerValue = .unkeyedContainer(values)
    }
}

extension ShapeSingleValueEncodingContainer: ShapeElement {
    public func getSerializedElements(_ key: String?, isRoot: Bool, elements: inout [(String, String?)]) throws {
        try delegate.serializedElementsForEncodingContainer(
            containerValue: containerValue,
            key: key,
            isRoot: isRoot,
            elements: &elements)
    }
    
    public func asRawShape() throws -> RawShape {
        return try delegate.rawShapeForEncodingContainer(containerValue: containerValue)
    }
}

extension ShapeSingleValueEncodingContainer: Swift.Encoder {
    var unkeyedContainerCount: Int {
        guard let containerValue = containerValue else {
            fatalError("Attempted to access unitialized container.")
        }

        guard case .unkeyedContainer(let values) = containerValue else {
            fatalError("Expected unkeyed container and there wasn't one.")
        }

        return values.count
    }

    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {

        // if there container is already initialized
        if let currentContainerValue = containerValue {
            guard case .keyedContainer = currentContainerValue else {
                fatalError("Trying to use an already initialized container as a keyed container.")
            }
        } else {
            containerValue = .keyedContainer([:])
        }

        let container = ShapeKeyedEncodingContainer<Key>(enclosingContainer: self)

        return KeyedEncodingContainer<Key>(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {

        // if there container is already initialized
        if let currentContainerValue = containerValue {
            guard case .unkeyedContainer = currentContainerValue else {
                fatalError("Trying to use an already initialized container as an unkeyed container.")
            }
        } else {
            containerValue = .unkeyedContainer([])
        }

        let container = ShapeUnkeyedEncodingContainer(enclosingContainer: self)

        return container
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}
