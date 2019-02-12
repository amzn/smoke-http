// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  DateISO8601Extensions.swift
//  ShapeCoding
//

import Foundation

private let iso8601DateFormatter: DateFormatter = {
     let formatter = DateFormatter()
     formatter.calendar = Calendar(identifier: .iso8601)
     formatter.locale = Locale(identifier: "en_US_POSIX")
     formatter.timeZone = TimeZone(secondsFromGMT: 0)
     formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
     return formatter
 }()

 extension Date {
     var iso8601: String {
         return iso8601DateFormatter.string(from: self)
     }
 }

 extension String {
     var dateFromISO8601: Date? {
         return iso8601DateFormatter.date(from: self)   // "Mar 22, 2017, 10:22 AM"
     }
 }
