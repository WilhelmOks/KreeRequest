import Foundation

public extension JSONDecoder.DateDecodingStrategy {
    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    nonisolated(unsafe) private static let dateFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let iso8601WithOptionalFractionalSeconds: Self = {
        return .custom { (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Workaround to work with both, fractional seconds and whole seconds.
            
            // Try whole seconds first:
            
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // If it fails, try fractional:
            
            if let date = dateFormatterWithFractionalSeconds.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Could not decode date from \(dateString).")
        }
    }()
}
