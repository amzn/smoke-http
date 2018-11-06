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
//  QueryUnkeyedEncodingContainer.swift
//  QueryCoder
//

import Foundation

internal struct QueryUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let enclosingContainer: QuerySingleValueEncodingContainer

    init(enclosingContainer: QuerySingleValueEncodingContainer) {
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

        let nestedKeyContainer = QueryKeyedEncodingContainer<NestedKey>(enclosingContainer: nestedContainer)

        return KeyedEncodingContainer<NestedKey>(nestedKeyContainer)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedContainer = createNestedContainer(defaultValue: .unkeyedContainer([]))

        let nestedKeyContainer = QueryUnkeyedEncodingContainer(enclosingContainer: nestedContainer)

        return nestedKeyContainer
    }

    func superEncoder() -> Encoder { return createNestedContainer() }

    // MARK: -

    private func createNestedContainer(defaultValue: ContainerValueType? = nil)
        -> QuerySingleValueEncodingContainer {
        let index = enclosingContainer.unkeyedContainerCount

        let nestedContainer = QuerySingleValueEncodingContainer(userInfo: enclosingContainer.userInfo,
                                                                codingPath: enclosingContainer.codingPath + [QueryCodingKey(index: index)],
                                                                options: enclosingContainer.options,
                                                                allowedCharacterSet: enclosingContainer.allowedCharacterSet,
                                                    defaultValue: defaultValue)
        enclosingContainer.addToUnkeyedContainer(value: nestedContainer)

        return nestedContainer
    }
}

private let iso8601DateFormatter: DateFormatter = {
     let formatter = DateFormatter()
     formatter.calendar = Calendar(identifier: .iso8601)
     formatter.locale = Locale(identifier: "en_US_POSIX")
     formatter.timeZone = TimeZone(secondsFromGMT: 0)
     formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
     return formatter
 }()

 extension Date {
     var iso8601: String {
         return iso8601DateFormatter.string(from: self)
     }
 }

 extension String {
     var dateFromISO8601: Date? {
         return iso8601DateFormatter.date(from: self)   // "Mar 22, 2017, 10:22 AM"
     }
 }
