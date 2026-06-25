import Foundation
import MCP

/// Runtime validation that mirrors ToolDefinitions input schemas for direct tool callers.
enum ToolArgumentValidation {

    struct Failure: Error {
        let code: String
        let message: String
        let remediation: String

        var result: CallTool.Result {
            ToolError.validation(code: code, message: message, remediation: remediation)
        }

        init(
            code: String,
            message: String,
            remediation: String = "Adjust the tool arguments to match the input schema and retry."
        ) {
            self.code = code
            self.message = message
            self.remediation = remediation
        }
    }

    static func rejectUnknown(
        _ arguments: [String: Value]?,
        allowed: Set<String>
    ) throws {
        guard let arguments else { return }
        let unknown = arguments.keys.filter { !allowed.contains($0) }.sorted()
        if let first = unknown.first {
            throw Failure(
                code: "validation.unknown_argument",
                message: "Unknown argument '\(first)'",
                remediation: "Remove '\(first)' or use one of the documented input schema properties."
            )
        }
    }

    static func requiredString(
        _ arguments: [String: Value]?,
        name: String,
        displayName: String? = nil
    ) throws -> String {
        guard let value = try optionalString(arguments, name: name), !value.isEmpty else {
            throw Failure(
                code: "validation.required_argument",
                message: "\(displayName ?? name) is required",
                remediation: "Provide \(name) using the tool input schema and retry."
            )
        }
        return value
    }

    static func optionalString(
        _ arguments: [String: Value]?,
        name: String
    ) throws -> String? {
        guard let raw = arguments?[name] else { return nil }
        guard let value = String(raw, strict: false) else {
            throw Failure(code: "validation.invalid_type", message: "\(name) must be a string")
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
            throw Failure(
                code: "validation.invalid_date",
                message: "\(name) must be yyyy-MM-dd or an ISO 8601 datetime",
                remediation: "Use yyyy-MM-dd or an ISO 8601 datetime with timezone information."
            )
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
            throw Failure(
                code: "validation.invalid_enum",
                message: "\(name) must be one of: \(allowed.sorted().joined(separator: ", "))",
                remediation: "Choose one of the documented enum values and retry."
            )
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
            throw Failure(code: "validation.invalid_type", message: "\(name) must be a boolean")
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
            throw Failure(code: "validation.invalid_type", message: "\(name) must be an integer")
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
            throw Failure(code: "validation.invalid_type", message: "\(name) must be an integer")
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
            throw Failure(
                code: "validation.required_argument",
                message: "\(name) is required",
                remediation: "Provide \(name) using the tool input schema and retry."
            )
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
            throw Failure(code: "validation.invalid_type", message: "\(name) must be a number")
        }
        if let minValue {
            if exclusiveMin {
                guard value > minValue else {
                    throw Failure(code: "validation.out_of_range", message: "\(name) must be greater than \(minValue)")
                }
            } else {
                guard value >= minValue else {
                    throw Failure(code: "validation.out_of_range", message: "\(name) must be at least \(minValue)")
                }
            }
        }
        if let maxValue, value > maxValue {
            throw Failure(code: "validation.out_of_range", message: "\(name) must be at most \(maxValue)")
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
            throw Failure(code: "validation.out_of_range", message: "\(name) must be at least \(minValue)")
        }
        if let maxValue, value > maxValue {
            throw Failure(code: "validation.out_of_range", message: "\(name) must be at most \(maxValue)")
        }
    }
}
