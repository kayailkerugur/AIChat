//
//  SSEEventParser.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Minimal, incremental Server-Sent Events parser. Feed it lines as
//  they arrive from URLSession.bytes; it returns a complete event's
//  data payload whenever a blank line (event boundary) is reached.
//
//  Implements the subset of the SSE spec that AI streaming APIs use:
//  - "data: ..." lines (multiple data lines join with \n)
//  - ": comment" lines are ignored
//  - blank line dispatches the accumulated event
//  Other fields (event:, id:, retry:) are ignored on purpose.
//
//  Pure value type with no I/O — trivially unit-testable, which is
//  exactly the spec's risk mitigation: "önce mock stream ve küçük
//  parser testleri hazırlanmalıdır".
//

import Foundation

struct SSEEventParser {

    private var dataLines: [String] = []

    /// Feed one line (without its trailing newline). Returns a complete
    /// event payload when this line closes an event, otherwise nil.
    mutating func feed(line: String) -> String? {
        // Blank line = event boundary → dispatch what we have.
        if line.isEmpty {
            return flushPending()
        }

        // Comment line — keep-alive pings etc.
        if line.hasPrefix(":") {
            return nil
        }

        if line.hasPrefix("data:") {
            var value = String(line.dropFirst("data:".count))
            // Per spec, a single leading space after the colon is stripped.
            if value.hasPrefix(" ") { value.removeFirst() }
            dataLines.append(value)
        }
        // Any other field (event:, id:, retry:) is intentionally ignored.

        return nil
    }

    /// Call once at end-of-stream: some servers close the connection
    /// without a trailing blank line after the last event.
    mutating func flushPending() -> String? {
        guard !dataLines.isEmpty else { return nil }
        defer { dataLines.removeAll() }
        return dataLines.joined(separator: "\n")
    }
}
