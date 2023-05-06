/// EOSIO time types.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// Type representing a timestamp with microsecond accuracy.
public struct TimePoint: RawRepresentable, Equatable, Hashable {
    internal static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()

    /// Microseconds since 1970.
    public var rawValue: Int64

    /// Create a new instance.
    /// - Parameter value: Microseconds since 1970.
    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    /// Create a new instance from a date.
    public init(_ date: Date) {
        self.rawValue = Int64(round(date.timeIntervalSince1970 * 1_000_000))
    }

    /// Create a new instance from a `TimePointSec`
    public init(_ timePointSec: TimePointSec) {
        self.rawValue = Int64(timePointSec.rawValue) * 1_000_000
    }

    /// Create a new instance from a ISO 8601-ish date.
    /// - Parameter stringValue: Date string, e.g. `2019-01-22T21:42:55.123`.
    public init?(_ stringValue: String) {
        guard let date = Self.dateFormatter.date(from: stringValue) else {
            return nil
        }
        self.init(date)
    }

    /// Date representation.
    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(self.rawValue) / 1_000_000)
    }

    /// ISO 8601-ish formatted string.
    public var stringValue: String {
        return TimePoint.dateFormatter.string(from: self.date)
    }

    /// Adds a time interval to this time point.
    public mutating func addTimeInterval(_ timeInterval: TimeInterval) {
        self.rawValue += Int64(round(timeInterval * 1_000_000))
    }

    /// Creates a new time point by adding a time interval.
    public func addingTimeInterval(_ timeInterval: TimeInterval) -> TimePoint {
        return TimePoint(rawValue: self.rawValue + Int64(round(timeInterval * 1_000_000)))
    }
}

/// Type representing a timestamp with second accuracy.
public struct TimePointSec: RawRepresentable, Equatable, Hashable {
    internal static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    /// Seconds sinze 1970.
    public var rawValue: UInt32

    /// Create a new instance from raw value.
    /// - Parameter value: Seconds since 1970.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Create a new instance from a Date.
    public init(_ date: Date) {
        self.rawValue = UInt32(date.timeIntervalSince1970)
    }

    /// Create a new instance from a TimePoint.
    public init(_ timePoint: TimePoint) {
        self.rawValue = UInt32(timePoint.rawValue / 1_000_000)
    }

    /// Create a new instance from a ISO 8601-ish date.
    /// - Parameter date: Date string, e.g. `2019-01-22T21:42:55`.
    public init?(_ date: String) {
        guard let date = Self.dateFormatter.date(from: date) else {
            return nil
        }
        self.rawValue = UInt32(date.timeIntervalSince1970)
    }

    /// Date representation.
    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(self.rawValue))
    }

    /// ISO 8601-ish formatted string.
    public var stringValue: String {
        return Self.dateFormatter.string(from: self.date)
    }

    /// Adds a time interval to this time point.
    public mutating func addTimeInterval(_ timeInterval: TimeInterval) {
        self.rawValue += UInt32(timeInterval)
    }

    /// Creates a new time point by adding a time interval.
    public func addingTimeInterval(_ timeInterval: TimeInterval) -> TimePointSec {
        return TimePointSec(rawValue: self.rawValue + UInt32(timeInterval))
    }
}

// MARK: ABI Coding

extension TimePoint: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let date = try container.decode(String.self)
        guard let instance = Self(date) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unable to decode date"
            )
        }
        self = instance
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(Int64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(self.rawValue)
    }
}

extension TimePointSec: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let instance = Self(try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unable to decode date"
            )
        }
        self = instance
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(UInt32.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(self.rawValue)
    }
}

// MARK: Language extensions

extension TimePoint: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let instance = TimePoint(value) else {
            fatalError("Invalid TimePoint literal")
        }
        self = instance
    }
}

extension TimePoint: LosslessStringConvertible {
    public var description: String {
        return self.stringValue
    }
}

extension TimePoint: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self.rawValue = value
    }
}

extension TimePointSec: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let instance = TimePointSec(value) else {
            fatalError("Invalid TimePointSec literal")
        }
        self = instance
    }
}

extension TimePointSec: LosslessStringConvertible {
    public var description: String {
        return self.stringValue
    }
}

extension TimePointSec: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

extension TimePoint: Comparable {
    public static func < (lhs: TimePoint, _: TimePoint) -> Bool {
        return lhs.rawValue < lhs.rawValue
    }
}

extension TimePointSec: Comparable {
    public static func < (lhs: TimePointSec, rhs: TimePointSec) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
