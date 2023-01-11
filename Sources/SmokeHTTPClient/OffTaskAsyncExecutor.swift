// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  OffTaskAsyncExecutor.swift
//  SmokeHTTPClient
//

import Foundation

/**
  Executes code off the Swift Concurrency cooperative thread pool.
  This executor is intended for computationally intensive work such as serialization and deserialization.
 */
internal struct OffTaskAsyncExecutor {
    internal func execute(_ body: @escaping () -> ()) async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                body()
                
                continuation.resume()
            }
        }
    }
    
    internal func execute(_ body: @escaping () throws -> ()) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try body()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    internal func execute<ReturnType>(_ body: @escaping () -> (ReturnType)) async -> ReturnType {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let result = body()
                
                continuation.resume(returning: result)
            }
        }
    }
    
    internal func execute<ReturnType>(_ body: @escaping () throws -> (ReturnType)) async throws -> ReturnType {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let result = try body()
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
