import Foundation

/// Optional cross-check for KnownObjectSizeCalibration: the user places the phone at
/// a known distance/height from contact (onboarding "framing guide"), and that fixed
/// geometry is used directly instead of inferring depth from the ball's apparent size.
struct GuidedPlacement {
    let distanceToContactMeters: Double
    let heightAboveGroundMeters: Double
}

/// Everything a CalibrationStrategy needs to turn a trajectory's normalized image
/// points into real-world positions. CalibrationEngine's callers build this from
/// CaptureKit's CameraGeometry so calibration code never has to import AVFoundation.
struct CalibrationContext {
    let frameWidthPixels: Int
    let frameHeightPixels: Int
    let horizontalFieldOfViewDegrees: Float
    let guidedPlacement: GuidedPlacement?
}

/// A trajectory point converted to meters, in the plane perpendicular to the camera
/// axis at that point's estimated depth. X is horizontal (camera-right positive),
/// Y is vertical (up positive).
struct CalibratedPoint {
    let xMeters: Double
    let yMeters: Double
    let depthMeters: Double
    let timestampSeconds: Double
}

struct CalibratedTrajectory {
    let points: [CalibratedPoint]
    let calibrationMethod: String
}
