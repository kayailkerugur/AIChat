import Foundation

enum RepositorySecretRedactor {
    private static let patterns = [
        #"(?im)\b(api[_-]?key|access[_-]?token|auth[_-]?token|secret|password)\b(\s*[:=]\s*)("[^"\r\n]+"|'[^'\r\n]+'|[^\s#,\r\n]+)"#,
        #"\b(sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9_]{12,})\b"#
    ]

    static func redact(_ content: String) -> (content: String, changed: Bool) {
        var result = content
        for (index, pattern) in patterns.enumerated() {
            guard let expression = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            let template = index == 0 ? "$1$2[REDACTED]" : "[REDACTED]"
            result = expression.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: template
            )
        }
        return (result, result != content)
    }
}
