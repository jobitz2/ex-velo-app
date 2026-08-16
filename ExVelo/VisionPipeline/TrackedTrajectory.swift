import CoreGraphics
import CoreMedia
import Vision

/// A Vision-independent snapshot of a detected trajectory, so CalibrationEngine
/// and PhysicsEngine don't need to import Vision or know about VNObservation.
struct TrackedTrajectory: Identifiable {
    /// A point on the tracked ball's path, normalized (0...1) with a lower-left origin.
    struct Point {
        let normalizedLocation: CGPoint
    }

    let id: UUID
    /// Measured centroid points, in temporal order, that fall within Vision's parabola tolerance.
    let detectedPoints: [Point]
    /// Coefficients (a, b, c) of the fitted parabola y = a*x^2 + b*x + c, in normalized image coordinates.
    let parabolaCoefficients: SIMD3<Float>
    let averageRadius: CGFloat
    let confidence: Float
    let timeRange: CMTimeRange

    init(observation: VNTrajectoryObservation) {
        id = observation.uuid
        detectedPoints = observation.detectedPoints.map { Point(normalizedLocation: $0.location) }
        parabolaCoefficients = observation.equationCoefficients
        averageRadius = observation.movingAverageRadius
        confidence = observation.confidence
        timeRange = observation.timeRange
    }
}
