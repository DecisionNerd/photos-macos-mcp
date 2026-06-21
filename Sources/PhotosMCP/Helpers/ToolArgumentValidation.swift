import Foundation
import MCP

/// Runtime validation that mirrors ToolDefinitions input schemas for direct tool callers.
enum ToolArgumentValidation {

    struct Failure: Error {
        let message: String

        var result: CallTool.Result {
            .init(content: [PhotoKitHelpers.textContent("Error: \(message)")], isError: true)
        }
    }

    static func rejectUnknown(
        _ arguments: [String: Value]?,
        allowed: Set<String>
    ) throws {
        guard let arguments else { return }
        let unknown = arguments.keys.filter { !allowed.contains($0) }.sorted()
        if let first = unknown.first {
            throw Failure(message: "Unknown argument '\(first)'")
        }
    }

    static func requiredString(
        _ arguments: [String: Value]?,
        name: String,
        displayName: String? = nil
    ) throws -> String {
        guard let value = try optionalString(arguments, name: name), !value.isEmpty else {
            throw Failure(message: "\(displayName ?? name) is required")
        }
        return value
    }

    static func optionalString(
        _ arguments: [String: Value]?,
        name: String
    ) throws -> String? {
        guard let raw = arguments?[name] else { return nil }
        guard let value = String(raw, strict: false) else {
            throw Failure(message: "\(name) must be a string")
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func optionalDateString(
        _ arguments: [String: Value]?,
        name: String
    ) throws -> String {
        guard let value = try optionalString(arguments, name: name), !value.isEmpty else {
            return ""
        }
        guard DateParsing.parse(value) != nil else {
            throw Failure(message: "\(name) must be yyyy-MM-dd or an ISO 8601 datetime")
        }
        return value
    }

    static func optionalEnum(
        _ arguments: [String: Value]?,
        name: String,
        default defaultValue: String,
        allowed: Set<String>
    ) throws -> String {
        let value = try optionalString(arguments, name: name) ?? defaultValue
        guard allowed.contains(value) else {
            throw Failure(message: "\(name) must be one of: \(allowed.sorted().joined(separator: ", "))")
        }
        return value
    }

    static func bool(
        _ arguments: [String: Value]?,
        name: String,
        default defaultValue: Bool
    ) throws -> Bool {
        guard let raw = arguments?[name] else { return defaultValue }
        guard let value = Bool(raw, strict: false) else {
            throw Failure(message: "\(name) must be a boolean")
        }
        return value
    }

    static func int(
        _ arguments: [String: Value]?,
        name: String,
        default defaultValue: Int,
        min minValue: Int? = nil,
        max maxValue: Int? = nil
    ) throws -> Int {
        guard let raw = arguments?[name] else { return defaultValue }
        guard let value = Int(raw, strict: false) else {
            throw Failure(message: "\(name) must be an integer")
        }
        try validateRange(value: value, name: name, min: minValue, max: maxValue)
        return value
    }

    static func optionalInt(
        _ arguments: [String: Value]?,
        name: String,
        min minValue: Int? = nil,
        max maxValue: Int? = nil
    ) throws -> Int? {
        guard let raw = arguments?[name] else { return nil }
        guard let value = Int(raw, strict: false) else {
            throw Failure(message: "\(name) must be an integer")
        }
        try validateRange(value: value, name: name, min: minValue, max: maxValue)
        return value
    }

    static func double(
        _ arguments: [String: Value]?,
        name: String,
        default defaultValue: Double,
        min minValue: Double? = nil,
        exclusiveMin: Bool = false,
        max maxValue: Double? = nil
    ) throws -> Double {
        guard let raw = arguments?[name] else { return defaultValue }
        return try requiredDoubleValue(raw, name: name, min: minValue, exclusiveMin: exclusiveMin, max: maxValue)
    }

    static func requiredDouble(
        _ arguments: [String: Value]?,
        name: String,
        min minValue: Double? = nil,
        exclusiveMin: Bool = false,
        max maxValue: Double? = nil
    ) throws -> Double {
        guard let raw = arguments?[name] else {
            throw Failure(message: "\(name) is required")
        }
        return try requiredDoubleValue(raw, name: name, min: minValue, exclusiveMin: exclusiveMin, max: maxValue)
    }

    private static func requiredDoubleValue(
        _ raw: Value,
        name: String,
        min minValue: Double?,
        exclusiveMin: Bool,
        max maxValue: Double?
    ) throws -> Double {
        guard let value = Double(raw, strict: false), value.isFinite else {
            throw Failure(message: "\(name) must be a number")
        }
        if let minValue {
            if exclusiveMin {
                guard value > minValue else { throw Failure(message: "\(name) must be greater than \(minValue)") }
            } else {
                guard value >= minValue else { throw Failure(message: "\(name) must be at least \(minValue)") }
            }
        }
        if let maxValue, value > maxValue {
            throw Failure(message: "\(name) must be at most \(maxValue)")
        }
        return value
    }

    private static func validateRange<T: Comparable & CustomStringConvertible>(
        value: T,
        name: String,
        min minValue: T?,
        max maxValue: T?
    ) throws {
        if let minValue, value < minValue {
            throw Failure(message: "\(name) must be at least \(minValue)")
        }
        if let maxValue, value > maxValue {
            throw Failure(message: "\(name) must be at most \(maxValue)")
        }
    }
}
