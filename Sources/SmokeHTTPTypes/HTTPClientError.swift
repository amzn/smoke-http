// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPClientError.swift
//  SmokeHTTPTypes
//

public struct HTTPClientError: Error {
    public let responseCode: Int
    public let cause: Swift.Error
    
    public enum Category {
        case clientError
        case serverError
    }
    
    public init(responseCode: Int, cause: Swift.Error) {
        self.responseCode = responseCode
        self.cause = cause
    }
    
    public var category: Category {
        switch responseCode {
        case 400...499:
            return .clientError
        default:
            return .serverError
        }
    }
    
    public func isRetriable() -> Bool {
        return self.isRetriableAccordingToCategory
    }
    
    public var isRetriableAccordingToCategory: Bool {
        if case self.category = Category.clientError {
            return false
        } else {
            return true
        }
    }
}
