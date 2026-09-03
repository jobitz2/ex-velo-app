import Foundation

/// The single entry point tying VelocityRegression (recover speed from calibrated
/// points) to the m/s -> mph conversion every reading is displayed in.
enum PhysicsEngine {
    static func computeSpeedMph(from calibrated: CalibratedTrajectory) -> Double? {
        guard let speedMetersPerSecond = VelocityRegression.speedMetersPerSecond(from: calibrated.points) else {
            return nil
        }
        return speedMetersPerSecond * 2.2369362920544
    }
}
