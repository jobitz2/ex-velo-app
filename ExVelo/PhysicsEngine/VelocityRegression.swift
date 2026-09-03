import Foundation

/// Recovers a tracked ball's speed by fitting its calibrated points to a parabola:
/// a linear fit for the (near-constant, over this short window) horizontal
/// velocity, and a quadratic fit for vertical motion under gravity. Speed is the
/// magnitude of that velocity vector at the first tracked point — this is a radar
/// gun, so only the reading matters, not the trajectory's shape.
enum VelocityRegression {
    static func speedMetersPerSecond(from points: [CalibratedPoint]) -> Double? {
        guard points.count >= 3 else { return nil }

        let xSamples = points.map { (t: $0.timestampSeconds, y: $0.xMeters) }
        let ySamples = points.map { (t: $0.timestampSeconds, y: $0.yMeters) }

        guard let xFit = LeastSquares.linearFit(xSamples),
              let yFit = LeastSquares.quadraticFit(ySamples) else {
            return nil
        }

        let vx = xFit.slope
        let vy = yFit.b // dy/dt at t=0 for y = a*t^2 + b*t + c

        return (vx * vx + vy * vy).squareRoot()
    }
}
