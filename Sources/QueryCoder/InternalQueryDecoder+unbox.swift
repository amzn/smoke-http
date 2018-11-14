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
//  InternalQueryDecoder+unbox.swift
//  QueryCoder
//

import Foundation

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
