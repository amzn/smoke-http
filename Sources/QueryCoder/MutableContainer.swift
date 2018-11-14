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
//  MutableContainer.swift
//  QueryCoder
//

import Foundation

// MARK: - Mutable Containers
internal class MutableContainerDictionary {
    private var values: [String: MutableQueryValue] = [:]
    
    subscript(key: String) -> MutableQueryValue? {
        get {
            return values[key]
        }
        set(newValue) {
            values[key] = newValue
        }
    }
    
    internal func asQueryValue() -> QueryValue {
        let transformedValues: [String: QueryValue] = values.mapValues { value in
            return value.asQueryValue()
        }
        
        return .dictionary(transformedValues)
    }
}

internal enum MutableQueryValue {
    case dictionary(MutableContainerDictionary)
    case string(String)
    case null
    
    internal func asQueryValue() -> QueryValue {
        switch self {
        case .dictionary(let innerDictionary):
            return innerDictionary.asQueryValue()
        case .string(let value):
            return .string(value)
        case .null:
            return .null
        }
    }
}

internal enum MutableContainer {
    case dictionary(MutableContainerDictionary)
    
    internal func asQueryValue() -> QueryValue {
        switch self {
        case .dictionary(let innerDictionary):
            return innerDictionary.asQueryValue()
        }
    }
}

// MARK: - Container
internal enum QueryValue: Equatable {
    case dictionary([String: QueryValue])
    case string(String)
    case null
}
