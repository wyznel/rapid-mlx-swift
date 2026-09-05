import Foundation

enum RapidMLXIntegrationTests {
    /// Live-server tests are opt-in so the package's unit suite stays reliable
    /// on CI and on machines where Rapid-MLX is not running.
    static let isEnabled = ProcessInfo.processInfo.environment[
        "RAPID_MLX_INTEGRATION_TESTS"
    ] == "1"
}
