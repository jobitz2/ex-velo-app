import Foundation

struct SwingKinematics {
    let exitVelocityMetersPerSecond: Double
    let launchAngleDegrees: Double
}

/// Recovers the initial velocity vector at contact by fitting the post-contact
/// points to a parabola: a linear fit for the (near-constant, over this short
/// window) horizontal velocity, and a quadratic fit for vertical motion under
/// gravity. This is a *local* fit purely to extract v0 at contact — DragFlightModel
/// is what projects the full flight forward from it, per docs/ASSESSMENT.md §2.5.
enum VelocityRegression {
    static func kinematics(
        from points: [CalibratedPoint],
        deviceLevelPitchDegrees: Double = 0
    ) -> SwingKinematics? {
        guard points.count >= 3 else { return nil }

        let xSamples = points.map { (t: $0.timestampSeconds, y: $0.xMeters) }
        let ySamples = points.map { (t: $0.timestampSeconds, y: $0.yMeters) }

        guard let xFit = LeastSquares.linearFit(xSamples),
              let yFit = LeastSquares.quadraticFit(ySamples) else {
            return nil
        }

        let vx = xFit.slope
        let vy = yFit.b // dy/dt at t=0 for y = a*t^2 + b*t + c

        let exitVelocity = (vx * vx + vy * vy).squareRoot()
        let rawLaunchAngleDegrees = atan2(vy, vx) * 180 / .pi
        // Corrects for the phone not being held perfectly level, using CoreMotion's
        // horizontal reference rather than the raw video frame.
        let launchAngleDegrees = rawLaunchAngleDegrees - deviceLevelPitchDegrees

        return SwingKinematics(exitVelocityMetersPerSecond: exitVelocity, launchAngleDegrees: launchAngleDegrees)
    }
}
