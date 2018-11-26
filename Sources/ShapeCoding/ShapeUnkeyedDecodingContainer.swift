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
//  ShapeUnkeyedDecodingContainer.swift
//  ShapeCoding
//

import Foundation

internal struct ShapeUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    // MARK: Properties
    
    /// A reference to the decoder we're reading from.
    private let decoder: ShapeDecoder
    
    /// A reference to the container we're reading from.
    private let container: [Shape]
    
    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]
    
    /// The index of the element we're about to decode.
    private(set) public var currentIndex: Int
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    internal init(referencing decoder: ShapeDecoder, wrapping container: [String: Shape],
                  isRoot: Bool) throws {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
        self.container = try decoder.delegate.getEntriesForUnkeyedContainer(
            wrapping: container,
            isRoot: isRoot,
            codingPath: decoder.codingPath)
    }
    
    internal init(referencing decoder: ShapeDecoder,
                  containerKey: CodingKey,
                  parentContainer: [String: Shape],
                  isRoot: Bool) throws {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
        self.container = try decoder.delegate.getEntriesForUnkeyedContainer(
            parentContainer: parentContainer,
            containerKey: containerKey,
            isRoot: isRoot,
            codingPath: decoder.codingPath)
    }
    
    // MARK: - UnkeyedDecodingContainer Methods
    
    public var count: Int? {
        return self.container.count
    }
    
    public var isAtEnd: Bool {
        return self.currentIndex >= self.count!
    }
    
    public mutating func decodeNil() throws -> Bool {
        guard !self.isAtEnd else {
            let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath + [ShapeCodingKey(index: self.currentIndex)],
                                                        debugDescription: "Unkeyed container is at end.")
            throw DecodingError.valueNotFound(Any?.self, decodingContext)
        }
        
        if case .null = self.container[self.currentIndex] {
            self.currentIndex += 1
            return true
        } else {
            return false
        }
    }
    
    internal mutating func decodeIntoType<ValueType: Decodable>(
        _ type: ValueType.Type,
        decodeFunction: (_ value: Shape?, _ decoder: ShapeDecoder) throws -> ValueType?) throws
        -> ValueType {
            guard !self.isAtEnd else {
                let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath + [ShapeCodingKey(index: self.currentIndex)],
                                                            debugDescription: "Unkeyed container is at end.")
                throw DecodingError.valueNotFound(type, decodingContext)
            }
            
            self.decoder.codingPath.append(ShapeCodingKey(index: self.currentIndex))
            defer { self.decoder.codingPath.removeLast() }
            
            guard let decoded = try decodeFunction(self.container[self.currentIndex], self.decoder) else {
                let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath + [ShapeCodingKey(index: self.currentIndex)],
                                                            debugDescription: "Expected \(type) but found nil instead.")
                throw DecodingError.valueNotFound(type, decodingContext)
            }
            
            self.currentIndex += 1
            return decoded
    }
    
    public mutating func decode(_ type: Bool.Type) throws -> Bool {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Bool.self)
        }
    }
    
    public mutating func decode(_ type: Int.Type) throws -> Int {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Int.self)
        }
    }
    
    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Int8.self)
        }
    }
    
    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Int16.self)
        }
    }
    
    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Int32.self)
        }
    }
    
    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Int64.self)
        }
    }
    
    public mutating func decode(_ type: UInt.Type) throws -> UInt {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: UInt.self)
        }
    }
    
    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: UInt8.self)
        }
    }
    
    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: UInt16.self)
        }
    }
    
    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: UInt32.self)
        }
    }
    
    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: UInt64.self)
        }
    }
    
    public mutating func decode(_ type: Float.Type) throws -> Float {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Float.self)
        }
    }
    
    public mutating func decode(_ type: Double.Type) throws -> Double {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: Double.self)
        }
    }
    
    public mutating func decode(_ type: String.Type) throws -> String {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: String.self)
        }
    }
    
    public mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try decodeIntoType(type) { (value, decoder) in
            return try decoder.unbox(value, as: type)
        }
    }
    
    public mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        self.decoder.codingPath.append(ShapeCodingKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            let debugDescription = "Cannot get nested keyed container -- unkeyed container is at end."
            throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: debugDescription))
        }
        
        let value = self.container[self.currentIndex]
        guard case .dictionary(let dictionary) = value else {
            throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String: Any].self, reality: value)
        }
        
        self.currentIndex += 1
        let container = try ShapeKeyedDecodingContainer<NestedKey>(referencing: self.decoder,
                                                                   wrapping: dictionary, isRoot: false)
        return KeyedDecodingContainer(container)
    }
    
    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(ShapeCodingKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            let debugDescription = "Cannot get nested keyed container -- unkeyed container is at end."
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: debugDescription))
        }
        
        let value = self.container[self.currentIndex]
        guard case .dictionary(let dictionary) = value else {
            throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String: Any].self, reality: value)
        }
        
        self.currentIndex += 1
        return try ShapeUnkeyedDecodingContainer(referencing: self.decoder, wrapping: dictionary, isRoot: false)
    }
    
    public mutating func superDecoder() throws -> Decoder {
        self.decoder.codingPath.append(ShapeCodingKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(Decoder.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get superDecoder() -- unkeyed container is at end."))
        }
        
        let value = self.container[self.currentIndex]
        self.currentIndex += 1
        return ShapeDecoder(decoderValue: value, isRoot: false, at: self.decoder.codingPath,
                           userInfo: self.decoder.userInfo,
                           delegate: self.decoder.delegate)
    }
}
