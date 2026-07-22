import Foundation

public struct SSEEventParser: Sendable {
    private var dataLines: [String] = []

    public init() {}

    public mutating func feed(line: String) -> String? {
        if line.isEmpty {
            return flushPending()
        }

        if line.hasPrefix(":") {
            return nil
        }

        if line.hasPrefix("data:") {
            var value = String(line.dropFirst("data:".count))
            if value.hasPrefix(" ") { value.removeFirst() }
            dataLines.append(value)
        }

        return nil
    }

    public mutating func flushPending() -> String? {
        guard !dataLines.isEmpty else { return nil }
        defer { dataLines.removeAll() }
        return dataLines.joined(separator: "\n")
    }
}
