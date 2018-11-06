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
//  QuerySingleValueEncodingContainer.swift
//  QueryCoder
//

import Foundation

internal class QuerySingleValueEncodingContainer: SingleValueEncodingContainer {
    internal var containerValue: ContainerValueType?

    let codingPath: [CodingKey]
    let allowedCharacterSet: CharacterSet?
    let userInfo: [CodingUserInfoKey: Any]
    let options: QueryEncoder._Options

    init(userInfo: [CodingUserInfoKey: Any],
         codingPath: [CodingKey],
         options: QueryEncoder._Options,
         allowedCharacterSet: CharacterSet?,
         defaultValue: ContainerValueType?) {
        self.containerValue = defaultValue
        self.userInfo = userInfo
        self.allowedCharacterSet = allowedCharacterSet
        self.codingPath = codingPath
        self.options = options
    }

    func encodeNil() throws {
        containerValue = .singleValue("")
    }

    func encode(_ value: Bool) throws {
        containerValue = .singleValue(value ? "true" : "false")
    }

    func encode(_ value: Int) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: Int8) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: Int16) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: Int32) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: Int64) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: UInt) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: UInt8) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: UInt16) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: UInt32) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: UInt64) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: Float) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: Double) throws {
        containerValue = .singleValue(String(value))
    }

    func encode(_ value: String) throws {
        let encodedValue: String
        if let allowedCharacterSet = allowedCharacterSet,
            let percentEncoded = value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                encodedValue = percentEncoded
        } else {
            encodedValue = value
        }

        containerValue = .singleValue(encodedValue)
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        if let date = value as? Foundation.Date {
            let dateAsString = date.iso8601

            containerValue = .singleValue(dateAsString)
            return
        }

        try value.encode(to: self)
    }

    func addToKeyedContainer<KeyType: CodingKey>(key: KeyType, value: QueryElement) {
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

    func addToUnkeyedContainer(value: QueryElement) {
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

extension QuerySingleValueEncodingContainer: QueryElement {
    func getQueryElements(_ key: String?, isRoot: Bool, elements: inout [String: String]) throws {
        guard let containerValue = containerValue else {
            fatalError("Attempted to access uninitialized container.")
        }

        switch containerValue {
        case .singleValue(let value):
            return try value.getQueryElements(key, isRoot: false, elements: &elements)
        case .unkeyedContainer(let values):
            if let key = key {
                try values.enumerated().forEach { (index, value) in
                    let innerkey = "\(key).\(index + 1)"
                    try value.getQueryElements(innerkey, isRoot: false, elements: &elements)
                }
            } else {
                throw QueryEncoderError.typeNotQueryCompatible("Lists cannot be used as a query element without a key")
            }
        case .keyedContainer(let values):
            let sortedValues = values.sorted { (left, right) in left.key < right.key }

            try sortedValues.enumerated().forEach { entry in
                let innerKey = entry.element.key
                let index = entry.offset
                let keyToUse: String

                if !isRoot, case let .separateQueryEntriesWith(keyTag: keyTag, valueTag: valueTag) = options.mapEncodingStrategy {
                    let keyQueryElementKey: String
                    if let baseKey = key {
                        keyQueryElementKey = "\(baseKey).\(index + 1).\(keyTag)"
                        keyToUse = "\(baseKey).\(index + 1).\(valueTag)"
                    } else {
                        keyQueryElementKey = "\(index + 1).\(keyTag)"
                        keyToUse = "\(index + 1).\(valueTag)"
                    }

                    // add an element for the key
                    elements[keyQueryElementKey] = innerKey
                } else {
                    if let baseKey = key {
                        keyToUse = "\(baseKey).\(innerKey)"
                    } else {
                        keyToUse = innerKey
                    }
                }

                try entry.element.value.getQueryElements(keyToUse, isRoot: false, elements: &elements)
            }
        }
    }
}

extension QuerySingleValueEncodingContainer: Swift.Encoder {
    var unkeyedContainerCount: Int {
        guard let containerValue = containerValue else {
            fatalError("Attempted to access unitialized container.")
        }

        guard case .unkeyedContainer(let values) = containerValue else {
            fatalError("Expected unkeyed container and there wasn't one.")
        }

        return values.count
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey  {

        // if there container is already initialized
        if let currentContainerValue = containerValue {
            guard case .keyedContainer = currentContainerValue else {
                fatalError("Trying to use an already initialized container as a keyed container.")
            }
        } else {
            containerValue = .keyedContainer([:])
        }

        let container = QueryKeyedEncodingContainer<Key>(enclosingContainer: self)

        return KeyedEncodingContainer<Key>(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {

        // if there container is already initialized
        if let currentContainerValue = containerValue {
            guard case .unkeyedContainer = currentContainerValue else {
                fatalError("Trying to use an already initialized container as an unkeyed container.")
            }
        } else {
            containerValue = .unkeyedContainer([])
        }

        let container = QueryUnkeyedEncodingContainer(enclosingContainer: self)

        return container
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

