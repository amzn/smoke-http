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
//  QueryKeyedDecodingContainer+KeyedDecodingContainerProtocol.swift
//  QueryCoder
//

import Foundation

// MARK: Decoding Containers
extension QueryKeyedDecodingContainer: KeyedDecodingContainerProtocol {
    
    // MARK: - KeyedDecodingContainerProtocol Methods
    
    public var allKeys: [Key] {
        return self.container.keys.compactMap { Key(stringValue: $0) }
    }
    
    public func contains(_ key: Key) -> Bool {
        return self.container[key.stringValue] != nil
    }
    
    public func decodeNil(forKey key: Key) throws -> Bool {
        if let entry = self.container[key.stringValue] {
            if case .null = entry {
                return true
            }
            
            return false
        } else {
            return true
        }
    }
    
    internal func decodeIfPresentIntoType<ValueType: Decodable>(
        _ type: ValueType.Type, forKey key: Key,
        decodeFunction: (_ value: QueryValue?, _ decoder: InternalQueryDecoder) throws -> ValueType?) throws
        -> ValueType? {
            guard let entry = self.container[key.stringValue] else {
                return nil
            }
            
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }
            
            return try decodeFunction(entry, self.decoder)
    }
    
    internal func decodeIntoType<ValueType: Decodable>(
        _ type: ValueType.Type, forKey key: Key,
        decodeFunction: (_ value: QueryValue?, _ decoder: InternalQueryDecoder) throws -> ValueType?) throws
        -> ValueType {
            guard let entry = self.container[key.stringValue] else {
                let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath,
                                                            debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\").")
                throw DecodingError.keyNotFound(key, decodingContext)
            }
            
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }
            
            guard let value = try decodeFunction(entry, self.decoder) else {
                let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath,
                                                            debugDescription: "Expected \(type) value but found nil instead.")
                throw DecodingError.valueNotFound(type, decodingContext)
            }
            
            return value
    }
    
    public func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Bool.self)
        }
    }
    
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Bool.self)
        }
    }
    
    public func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int.self)
        }
    }
    
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int.self)
        }
    }
    
    public func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int8.self)
        }
    }
    
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int8.self)
        }
    }
    
    public func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int16.self)
        }
    }
    
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int16.self)
        }
    }
    
    public func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int32.self)
        }
    }
    
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int32.self)
        }
    }
    
    public func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int64.self)
        }
    }
    
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Int64.self)
        }
    }
    
    public func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt.self)
        }
    }
    
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt.self)
        }
    }
    
    public func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt8.self)
        }
    }
    
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt8.self)
        }
    }
    
    public func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt16.self)
        }
    }
    
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt16.self)
        }
    }
    
    public func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt32.self)
        }
    }
    
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt32.self)
        }
    }
    
    public func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt64.self)
        }
    }
    
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: UInt64.self)
        }
    }
    
    public func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Float.self)
        }
    }
    
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Float.self)
        }
    }
    
    public func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Double.self)
        }
    }
    
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return try decodeIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: Double.self)
        }
    }
    
    public func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: String.self)
        }
    }
    
    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let entry = self.container[key.stringValue] else {
            let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath,
                                                        debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\").")
            throw DecodingError.keyNotFound(key, decodingContext)
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: String.self) else {
            // treat a missing but required string as an empty string
            return ""
        }
        
        return value
    }
    
    public func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        return try decodeIfPresentIntoType(type, forKey: key) { (value, decoder) in
            return try decoder.unbox(value, as: type)
        }
    }
    
    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let entry = self.container[key.stringValue] else {
            let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath,
                                                        debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\").")
            throw DecodingError.keyNotFound(key, decodingContext)
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: type) else {
            if type == Data.self {
                // treat a missing but required Data as an empty Data
                guard let convertedValue = Data() as? T else {
                    fatalError("Unable to convert empty data to expected generic type '\(type)'.")
                }
                
                return convertedValue
            }
            
            let decodingContext = DecodingError.Context(codingPath: self.decoder.codingPath,
                                                        debugDescription: "Expected \(type) value but found nil instead.")
            throw DecodingError.valueNotFound(type, decodingContext)
        }
        
        return value
    }
    
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = self.container[key.stringValue] else {
            let decodingContext = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Cannot get \(KeyedDecodingContainer<NestedKey>.self) -- no value found for key \"\(key.stringValue)\"")
            throw DecodingError.keyNotFound(key, decodingContext)
        }
        
        guard case .dictionary(let dictionary) = value else {
            throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String: Any].self, reality: value)
        }
        
        let container = try QueryKeyedDecodingContainer<NestedKey>(referencing: self.decoder,
                                                                    wrapping: dictionary, isRoot: false)
        return KeyedDecodingContainer(container)
    }
    
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = self.container[key.stringValue] else {
            let decodingContext = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Cannot get UnkeyedDecodingContainer -- no value found for key \"\(key.stringValue)\"")
            throw DecodingError.keyNotFound(key, decodingContext)
        }
        
        guard case .dictionary(let dictionary) = value else {
            throw DecodingError.typeMismatch(at: self.codingPath, expectation: [String: Any].self, reality: value)
        }
        
        return try QueryUnkeyedDecodingContainer(referencing: self.decoder, wrapping: dictionary)
    }
    
    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        let value = self.container[key.stringValue]
        return InternalQueryDecoder(decoderValue: value, isRoot: false, at: self.decoder.codingPath,
                           userInfo: self.decoder.userInfo, options: self.decoder.options)
    }
    
    public func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: QueryCodingKey.super)
    }
    
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
}
