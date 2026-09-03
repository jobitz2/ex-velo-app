import Foundation

/// Everything KnownObjectSizeCalibration needs to turn a trajectory's normalized
/// image points into real-world positions. Built by callers from CaptureKit's
/// CameraGeometry so calibration code never has to import AVFoundation.
struct CalibrationContext {
    let frameWidthPixels: Int
    let frameHeightPixels: Int
    let horizontalFieldOfViewDegrees: Float
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
}
