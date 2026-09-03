import Foundation

/// The single entry point tying VelocityRegression (recover speed from calibrated
/// points) to the m/s -> mph conversion every reading is displayed in.
enum PhysicsEngine {
    /// A generous bound on speeds worth trusting — comfortably covers soft toss
    /// through a hard-hit exit velocity, while rejecting the wildly implausible
    /// readings that camera shake or background clutter can otherwise produce
    /// (a spurious trajectory from a shaky handheld frame regressing out to,
    /// say, 400mph is obviously noise, not a real ball).
    static let plausibleSpeedRangeMph: ClosedRange<Double> = 15...120

    static func computeSpeedMph(from calibrated: CalibratedTrajectory) -> Double? {
        guard let speedMetersPerSecond = VelocityRegression.speedMetersPerSecond(from: calibrated.points) else {
            return nil
        }
        let speedMph = speedMetersPerSecond * 2.2369362920544
        guard plausibleSpeedRangeMph.contains(speedMph) else { return nil }
        return speedMph
    }
}
