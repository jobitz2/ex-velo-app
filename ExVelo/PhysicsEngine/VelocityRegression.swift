import Foundation

/// Recovers a tracked ball's speed by fitting its calibrated points to motion in
/// all three axes: a linear fit for the (near-constant, over this short window)
/// horizontal velocity, a quadratic fit for vertical motion under gravity, and a
/// linear fit for depth (toward/away from the camera) — without that third axis,
/// a ball thrown at or past the camera, or on any path that isn't purely lateral,
/// would read as slower than it actually is, since only its in-plane motion would
/// be measured. Speed is the magnitude of the full 3D velocity vector at the
/// first tracked point.
enum VelocityRegression {
    static func speedMetersPerSecond(from points: [CalibratedPoint]) -> Double? {
        guard points.count >= 3 else { return nil }

        let xSamples = points.map { (t: $0.timestampSeconds, y: $0.xMeters) }
        let ySamples = points.map { (t: $0.timestampSeconds, y: $0.yMeters) }
        let zSamples = points.map { (t: $0.timestampSeconds, y: $0.depthMeters) }

        guard let xFit = LeastSquares.linearFit(xSamples),
              let yFit = LeastSquares.quadraticFit(ySamples),
              let zFit = LeastSquares.linearFit(zSamples) else {
            return nil
        }

        let vx = xFit.slope
        let vy = yFit.b // dy/dt at t=0 for y = a*t^2 + b*t + c
        let vz = zFit.slope // rate of change of depth: closing/receding speed

        return (vx * vx + vy * vy + vz * vz).squareRoot()
    }
}
