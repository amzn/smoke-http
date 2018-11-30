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
//  ShapeDecoder.swift
//  ShapeCoding
//

import Foundation

/// Internal Decoder instance used to decode Shapes into a Swift object.
public class ShapeDecoder: Decoder {
    public var userInfo: [CodingUserInfoKey: Any]
    internal(set) public var codingPath: [CodingKey]
    
    internal var decoderValue: Shape?
    internal let delegate: ShapeDecoderDelegate
    internal let isRoot: Bool
    
    /**
     Initializer.
     */
    public init(decoderValue: Shape?, isRoot: Bool, at codingPath: [CodingKey] = [],
                userInfo: [CodingUserInfoKey: Any],
                delegate: ShapeDecoderDelegate) {
        self.decoderValue = decoderValue
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.delegate = delegate
        self.isRoot = isRoot
    }
    
    // MARK: - Decoder Methods
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let currentValue = decoderValue else {
            let debugDescription = "Cannot get keyed decoding container -- found null value instead."
            throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: debugDescription))
        }
        
        guard case .dictionary(let dictionary) = currentValue else {
            throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String: Any].self, reality: currentValue)
        }
        
        let container = try ShapeKeyedDecodingContainer<Key>(referencing: self, wrapping: dictionary, isRoot: isRoot)
        return KeyedDecodingContainer(container)
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let currentValue = decoderValue else {
            let debugDescription = "Cannot get unkeyed decoding container -- found null value instead."
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: debugDescription))
        }
        
        guard case .dictionary(let dictionary) = currentValue else {
            throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String: Any].self, reality: currentValue)
        }
                
        return try ShapeUnkeyedDecodingContainer(referencing: self, wrapping: dictionary, isRoot: isRoot)
    }
    
    public func singleValueContainer() -> SingleValueDecodingContainer {
        return self
    }
}

extension ShapeDecoder: SingleValueDecodingContainer {
    // MARK: SingleValueDecodingContainer Methods
    
    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.codingPath,
                                                                          debugDescription: "Expected \(type) but found null value instead."))
        }
    }
    
    public func decodeNil() -> Bool {
        guard let currentValue = decoderValue else {
            return false
        }
        
        if case .null = currentValue {
            return true
        }
        return false
    }
    
    public func decode(_ type: Bool.Type) throws -> Bool {
        guard let decoded = try self.unbox(decoderValue, as: Bool.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Bool but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: Int.Type) throws -> Int {
        guard let decoded = try self.unbox(decoderValue, as: Int.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Int but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: Int8.Type) throws -> Int8 {
        guard let decoded = try self.unbox(decoderValue, as: Int8.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Int8 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: Int16.Type) throws -> Int16 {
        guard let decoded = try self.unbox(decoderValue, as: Int16.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Int16 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: Int32.Type) throws -> Int32 {
        guard let decoded = try self.unbox(decoderValue, as: Int32.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Int32 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: Int64.Type) throws -> Int64 {
        guard let decoded = try self.unbox(decoderValue, as: Int64.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Int64 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: UInt.Type) throws -> UInt {
        guard let decoded = try self.unbox(decoderValue, as: UInt.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected UInt but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard let decoded = try self.unbox(decoderValue, as: UInt8.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected UInt8 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard let decoded = try self.unbox(decoderValue, as: UInt16.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected UInt16 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard let decoded = try self.unbox(decoderValue, as: UInt32.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected UInt32 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard let decoded = try self.unbox(decoderValue, as: UInt64.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected UInt64 but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: Float.Type) throws -> Float {
        guard let decoded = try self.unbox(decoderValue, as: Float.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Float but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: Double.Type) throws -> Double {
        guard let decoded = try self.unbox(decoderValue, as: Double.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected Double but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode(_ type: String.Type) throws -> String {
        guard let decoded = try self.unbox(decoderValue, as: String.self) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected String but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
    
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        guard let decoded = try self.unbox(decoderValue, as: type) else {
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected \(type) but found nil instead.")
            throw DecodingError.valueNotFound(type, context)
        }
        return decoded
    }
}
