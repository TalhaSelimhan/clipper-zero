import LocalAuthentication

enum AuthenticationService {
    private static var lastAuthTime: Date?
    private static let cooldownInterval: TimeInterval = 60

    static func authenticate(reason: String = "Access secure content") async -> Bool {
        if let lastAuth = lastAuthTime, Date.now.timeIntervalSince(lastAuth) < cooldownInterval {
            return true
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                lastAuthTime = .now
            }
            return success
        } catch {
            return false
        }
    }
}
