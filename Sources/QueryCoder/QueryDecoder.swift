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
//  QueryDecoder.swift
//  QueryCoder
//

import Foundation

/**
 Decode query strings into Swift types.
 */
public struct QueryDecoder {
    private let options: Options
    private let userInfo: [CodingUserInfoKey: Any]
    
    /// The strategy to use for decoding query keys.
    public enum QueryKeyDecodingStrategy {
        /// The decoder will spilt query keys on the '.' character to indicate a
        /// nested structure that could include nested types, dictionaries and arrays. This is the default.
        ///
        /// Array entries are indicated by a 1-based index
        /// ie. ?theArray.1=Value1&theArray.2=Value2 --> QueryOutput(theArray: ["Value1", "Value2"])
        /// Nested type attributes are indicated by the attribute keys
        /// ie. ?theType.foo=Value1&theType.bar=Value2 --> QueryOutput(theType: TheType(foo: "Value1", bar: "Value2"))
        /// Dictionary entries are indicated based on the provided `MapDecodingStrategy`
        case useDotAsContainerSeparator
        
        /// The decoder will decode query keys into the attributes
        /// of the provided type. No nested types, lists or dictionaries are possible.
        case flatStructure
    }
    
    /// The strategy to use for decoding maps.
    public enum MapDecodingStrategy {
        /// The decoder will expect a single query entry for
        /// each entry of the map. This is the default.
        /// ie. ?theMap.Key=Value --> QueryOutput(theMap: ["Key": "Value"])
        case singleQueryEntry

        /// The decoder will expect separate entries for the key and value
        /// of each entry of the map, specified as a list.
        /// ie. ?theMap.1.KeyTag=Key&theMap.1.ValueTag=Value -> QueryOutput(theMap: ["Key": "Value"])
        case separateQueryEntriesWith(keyTag: String, valueTag: String)
    }
    
    // Structure that hold the options to use during decoding
    internal struct Options {
        let queryKeyDecodingStrategy: QueryKeyDecodingStrategy
        let mapDecodingStrategy: MapDecodingStrategy
    }
    
    /**
     Initializer.
     */
    public init(userInfo: [CodingUserInfoKey: Any] = [:],
                queryKeyDecodingStrategy: QueryKeyDecodingStrategy = .useDotAsContainerSeparator,
                mapDecodingStrategy: MapDecodingStrategy = .singleQueryEntry) {
        self.options = Options(queryKeyDecodingStrategy: queryKeyDecodingStrategy,
                                mapDecodingStrategy: mapDecodingStrategy)
        self.userInfo = userInfo
    }
    
    /**
     Decodes a string that represents an query string into an
     instance of the specified type.
 
     - Parameters:
        - type: The type of the value to decode.
        - data: The data to decode from.
     - returns: A value of the requested type.
     - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or
                if the given string is not a valid query.
     - throws: An error if any value throws an error during decoding.
     */
    public func decode<T: Decodable>(_ type: T.Type, from query: String) throws -> T {
        let queryValue = try QueryStackParser.parse(with: query, decoderOptions: options)
        
        let decoder = InternalQueryDecoder(decoderValue: queryValue, isRoot: true, userInfo: userInfo,
                                  options: self.options)
        
        guard let value = try decoder.unbox(queryValue, as: type, isRoot: true) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [],
                                                                          debugDescription: "The given data did not contain a top-level value."))
        }
        
        return value
    }
}

/// Internal Decoder instance used to decode QueryValues into a Swift object.
internal class InternalQueryDecoder: Decoder {
    public var userInfo: [CodingUserInfoKey: Any]
    internal(set) public var codingPath: [CodingKey]
    
    internal var decoderValue: QueryValue?
    internal let options: QueryDecoder.Options
    internal let isRoot: Bool
    
    /**
     Initializer.
     */
    internal init(decoderValue: QueryValue?, isRoot: Bool, at codingPath: [CodingKey] = [],
                  userInfo: [CodingUserInfoKey: Any], options: QueryDecoder.Options) {
        self.decoderValue = decoderValue
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.options = options
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
        
        let container = try QueryKeyedDecodingContainer<Key>(referencing: self, wrapping: dictionary, isRoot: isRoot)
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
        
        return try QueryUnkeyedDecodingContainer(referencing: self, wrapping: dictionary)
    }
    
    public func singleValueContainer() -> SingleValueDecodingContainer {
        return self
    }
}

extension InternalQueryDecoder: SingleValueDecodingContainer {
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

// MARK: - Concrete Value Representations
extension InternalQueryDecoder {
    
    /// Returns the given value unboxed from a container.
    internal func unbox(_ value: QueryValue?, as type: Bool.Type) throws -> Bool? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        switch unboxedValue.lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
    }
    
    internal func unbox(_ value: QueryValue?, as type: Int.Type) throws -> Int? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Int(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Int8.Type) throws -> Int8? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Int8(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Int16.Type) throws -> Int16? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Int16(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Int32.Type) throws -> Int32? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Int32(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Int64.Type) throws -> Int64? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Int64(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: UInt.Type) throws -> UInt? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = UInt(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: UInt8.Type) throws -> UInt8? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = UInt8(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: UInt16.Type) throws -> UInt16? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = UInt16(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: UInt32.Type) throws -> UInt32? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = UInt32(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: UInt64.Type) throws -> UInt64? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = UInt64(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Float.Type) throws -> Float? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Float(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Double.Type) throws -> Double? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Double(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: String.Type) throws -> String? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        return unboxedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Date.Type) throws -> Date? {
        guard let currentValue = value else {
            return nil
        }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = unboxedValue.dateFromISO8601 else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Data.Type) throws -> Data? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedValue = Data(base64Encoded: unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return convertedValue
    }
    
    internal func unbox(_ value: QueryValue?, as type: Decimal.Type) throws -> Decimal? {
        guard let currentValue = value else { return nil }
        
        guard case .string(let unboxedValue) = currentValue else {
            return nil
        }
        
        guard let convertedDoubleValue = Double(unboxedValue) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Expected \(type) but found '\(unboxedValue)' instead."))
        }
        
        return Decimal(convertedDoubleValue)
    }
    
    internal func unbox<T: Decodable>(_ value: QueryValue?, as type: T.Type, isRoot: Bool = false) throws -> T? {
        let decoded: T
        if type == Date.self {
            guard let date = try self.unbox(value, as: Date.self) else { return nil }
            guard let convertedValue = date as? T else {
                fatalError("Unable to convert '\(date)' to expected generic type '\(type)'.")
            }
            
            decoded = convertedValue
        } else if type == Data.self {
            guard let data = try self.unbox(value, as: Data.self) else { return nil }
            guard let convertedValue = data as? T else {
                fatalError("Unable to convert '\(data)' to expected generic type '\(type)'.")
            }
            
            decoded = convertedValue
        } else if type == URL.self {
            guard let urlString = try self.unbox(value, as: String.self) else {
                return nil
            }
            
            guard let url = URL(string: urlString) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                        debugDescription: "Invalid URL string."))
            }
            
            guard let convertedValue = url as? T else {
                fatalError("Unable to convert '\(url)' to expected generic type '\(type)'.")
            }
            
            decoded = convertedValue
        } else if type == Decimal.self {
            guard let decimal = try self.unbox(value, as: Decimal.self) else { return nil }
            guard let convertedValue = decimal as? T else {
                fatalError("Unable to convert '\(decimal)' to expected generic type '\(type)'.")
            }
            
            decoded = convertedValue
        } else {
            let newDecoder = InternalQueryDecoder(decoderValue: value,
                                           isRoot: isRoot,
                                           at: codingPath,
                                           userInfo: userInfo,
                                           options: options)
            decoded = try type.init(from: newDecoder)
        }
        
        return decoded
    }
}
