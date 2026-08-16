import Foundation

/// Pure pinhole-camera math shared by every calibration strategy.
enum CalibrationMath {
    /// Focal length in pixels, derived from the format's horizontal field of view.
    /// This is an MVP approximation of the camera's intrinsic focal length: precise
    /// per-frame intrinsics (kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix)
    /// require enabling intrinsic matrix delivery at capture time and aren't
    /// preserved once a clip is written to disk, so this derives an equivalent
    /// value from the format's reported field of view instead.
    static func focalLengthPixels(imageWidthPixels: Int, horizontalFieldOfViewDegrees: Float) -> Double {
        let halfWidth = Double(imageWidthPixels) / 2
        let halfFOVRadians = Double(horizontalFieldOfViewDegrees) / 2 * .pi / 180
        return halfWidth / tan(halfFOVRadians)
    }

    /// Converts a pixel offset from the principal point into a real-world offset,
    /// in meters, at the given depth.
    static func metersPerPixel(depthMeters: Double, focalLengthPixels: Double) -> Double {
        depthMeters / focalLengthPixels
    }
}
