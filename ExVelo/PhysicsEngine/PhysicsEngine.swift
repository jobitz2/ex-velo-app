import Foundation

struct SwingMetrics: Equatable {
    let exitVelocityMetersPerSecond: Double
    let launchAngleDegrees: Double
    let estimatedDistanceMeters: Double

    var exitVelocityMph: Double { exitVelocityMetersPerSecond * 2.2369362920544 }
    var estimatedDistanceFeet: Double { estimatedDistanceMeters * 3.280839895013123 }
}

/// The single entry point tying VelocityRegression (recover v0 from tracked points)
/// to DragFlightModel (project v0 forward into a distance estimate).
enum PhysicsEngine {
    static func computeMetrics(
        from calibrated: CalibratedTrajectory,
        deviceLevelPitchDegrees: Double = 0
    ) -> SwingMetrics? {
        guard let kinematics = VelocityRegression.kinematics(
            from: calibrated.points,
            deviceLevelPitchDegrees: deviceLevelPitchDegrees
        ) else {
            return nil
        }

        let flight = DragFlightModel.project(
            exitVelocityMetersPerSecond: kinematics.exitVelocityMetersPerSecond,
            launchAngleDegrees: kinematics.launchAngleDegrees
        )

        return SwingMetrics(
            exitVelocityMetersPerSecond: kinematics.exitVelocityMetersPerSecond,
            launchAngleDegrees: kinematics.launchAngleDegrees,
            estimatedDistanceMeters: flight.carryDistanceMeters
        )
    }
}
