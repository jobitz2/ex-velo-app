import Foundation

/// Fallback/cross-check strategy: the user places the phone at an app-specified
/// distance and height (onboarding framing guide), and that fixed geometry is used
/// directly instead of inferring depth from the ball's apparent size. Only
/// available when a GuidedPlacement has actually been set, per docs/ASSESSMENT.md §2.4.2.
struct GuidedPlacementCalibration: CalibrationStrategy {
    func calibrate(trajectory: TrackedTrajectory, context: CalibrationContext) -> CalibratedTrajectory? {
        guard let placement = context.guidedPlacement, !trajectory.detectedPoints.isEmpty else { return nil }

        let focalLengthPixels = CalibrationMath.focalLengthPixels(
            imageWidthPixels: context.frameWidthPixels,
            horizontalFieldOfViewDegrees: context.horizontalFieldOfViewDegrees
        )

        let points = CalibrationGeometry.points(
            from: trajectory,
            depthMeters: placement.distanceToContactMeters,
            focalLengthPixels: focalLengthPixels,
            context: context,
            heightOffsetMeters: placement.heightAboveGroundMeters
        )
        return CalibratedTrajectory(points: points, calibrationMethod: "guided-placement")
    }
}
