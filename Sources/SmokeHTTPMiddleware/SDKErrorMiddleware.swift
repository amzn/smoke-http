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
//  SDKErrorMiddleware.swift
//  SmokeHTTPMiddleware
//

import SwiftMiddleware
import ClientRuntime
import AwsCommonRuntimeKit

public struct SDKErrorMiddleware<ErrorResponseTransformType: TransformProtocol>: MiddlewareProtocol
where ErrorResponseTransformType.Input == HttpResponse {
    public typealias Input = SmokeSdkHttpRequestBuilder
    public typealias Output = HttpResponse
    public typealias Context = ErrorResponseTransformType.Context
    
    public let errorResponseTransform: ErrorResponseTransformType
        
    public init(errorResponseTransform: ErrorResponseTransformType) {
        self.errorResponseTransform = errorResponseTransform
    }
    
    public func handle(_ input: SmokeSdkHttpRequestBuilder, context: Context,
                       next: (SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws
    -> HttpResponse {
        do {
            let response = try await next(input, context)
            
            if (200..<300).contains(response.statusCode.rawValue) {
                return response
            } else {
                let error = try await self.errorResponseTransform.transform(response, context: context)
                throw SdkError.service(error, response)
            }
        // if a `CommonRunTimeError` is thrown
        } catch let error as CommonRunTimeError {
            // wrap it appropriately
            throw SdkError<Output>.client(.crtError(error))
        // if some unknown error happened
        } catch {
            // wrap it appropriately
            throw SdkError<Output>.client(.networkError(error))
        }
    }
}





// CommonRunTimeError
