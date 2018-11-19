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
//  ShapeDecodingStorage.swift
//  ShapeCoding
//

import Foundation

/// Helper class to store a stack of the current MutableShape to use when decoding a shape.
class ShapeDecodingStorage {
    private(set) internal var shapes: [NestableMutableShape] = []

    /// Initializer with no shapes.
    public init() {}

    /// The current number of shapes
    public var count: Int {
        return self.shapes.count
    }

    /// Retreive the current top shape
    public var topShape: NestableMutableShape? {
        return self.shapes.last
    }

    /// Push a new stack into the stack
    public func push(shape: NestableMutableShape) {
        self.shapes.append(shape)
    }

    /// Pop the top shape off the stack.
    public func popShape() {
        precondition(self.shapes.count > 0, "Empty shape stack.")
        self.shapes.removeLast()
    }
}
