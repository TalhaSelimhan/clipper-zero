import Foundation

enum SensitiveContentDetector {
    struct DetectionResult {
        let label: String
        let maskedPreview: String
    }

    static func detect(plainText: String?, contentType: ClipContentType, fileName: String?) -> DetectionResult? {
        // Check sensitive file extensions first
        if let fileName {
            let ext = (fileName as NSString).pathExtension.lowercased()
            let sensitiveExtensions = ["env", "p8", "pem", "key", "pfx", "p12"]
            if sensitiveExtensions.contains(ext) {
                return DetectionResult(label: "Sensitive File", maskedPreview: mask(fileName))
            }
        }

        guard let text = plainText, !text.isEmpty else { return nil }

        // Check text patterns
        for pattern in patterns {
            if pattern.matches(text) {
                return DetectionResult(label: pattern.label, maskedPreview: mask(text))
            }
        }

        return nil
    }

    static func mask(_ text: String, visibleChars: Int = 4) -> String {
        guard !text.isEmpty else { return "****" }

        // Multi-line: take first line only, then mask
        let firstLine: String
        if text.contains("\n") {
            firstLine = String(text.prefix(while: { $0 != "\n" }))
        } else {
            firstLine = text
        }

        guard firstLine.count > visibleChars else { return "****" }
        return String(firstLine.prefix(visibleChars)) + "****"
    }

    // MARK: - Pattern Definitions

    private struct Pattern {
        let label: String
        let regex: NSRegularExpression?
        let customMatch: (@Sendable (String) -> Bool)?

        init(label: String, pattern: String) {
            self.label = label
            self.regex = try? NSRegularExpression(pattern: pattern)
            self.customMatch = nil
        }

        init(label: String, match: @escaping @Sendable (String) -> Bool) {
            self.label = label
            self.regex = nil
            self.customMatch = match
        }

        func matches(_ text: String) -> Bool {
            if let customMatch {
                return customMatch(text)
            }
            guard let regex else { return false }
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, range: range) != nil
        }
    }

    private static let patterns: [Pattern] = [
        Pattern(label: "JWT Token", pattern: #"eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+"#),
        Pattern(label: "OpenAI Key", pattern: #"sk-[a-zA-Z0-9]{20,}"#),
        Pattern(label: "AWS Key", pattern: #"AKIA[0-9A-Z]{16}"#),
        Pattern(label: "GitHub Token", pattern: #"(gh[ps]_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]+|github_pat_[a-zA-Z0-9_]+)"#),
        Pattern(label: "GitLab Token", pattern: #"glpat-[a-zA-Z0-9\-]{20,}"#),
        Pattern(label: "Bearer Token", pattern: #"Bearer\s+[A-Za-z0-9._~+/=-]{20,}"#),
        Pattern(label: "Private Key", pattern: #"-----BEGIN\s+(RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"#),
        Pattern(label: "Connection String", pattern: #"(postgres|mysql|mongodb|redis|amqp)://\S+"#),
        Pattern(label: "Environment Variables", match: isEnvContent),
    ]

    private nonisolated static func isEnvContent(_ text: String) -> Bool {
        let lines = text.components(separatedBy: "\n")
        let envPattern = try? NSRegularExpression(pattern: #"^[A-Z_]+=\S+"#, options: .anchorsMatchLines)
        let sensitiveKeys = try? NSRegularExpression(pattern: #"(SECRET|TOKEN|PASSWORD|API_KEY|PRIVATE)"#)

        var matchCount = 0
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let envPattern, envPattern.firstMatch(in: line, range: range) != nil else { continue }
            guard let sensitiveKeys, sensitiveKeys.firstMatch(in: line, range: range) != nil else { continue }
            matchCount += 1
        }
        return matchCount >= 3
    }
}
