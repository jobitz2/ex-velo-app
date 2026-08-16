import AVFoundation
import CoreMedia

struct CaptureFormatSelection {
    let format: AVCaptureDevice.Format
    let maxFrameRate: Double
    let dimensions: CMVideoDimensions
}

enum CameraFormatSelector {
    static let targetFrameRate: Double = 240
    static let minimumAcceptableFrameRate: Double = 120

    /// Picks the format with the highest achievable frame rate. Ties are broken by
    /// smallest resolution, since a narrower frame at the same fps is easier for
    /// VisionPipeline to track a fast-moving ball in.
    static func selectBestFormat(for device: AVCaptureDevice) -> CaptureFormatSelection? {
        let candidates: [CaptureFormatSelection] = device.formats.compactMap { format in
            guard let range = format.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }) else {
                return nil
            }
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return CaptureFormatSelection(format: format, maxFrameRate: range.maxFrameRate, dimensions: dimensions)
        }
        guard let maxRate = candidates.map(\.maxFrameRate).max() else { return nil }
        let atMaxRate = candidates.filter { $0.maxFrameRate == maxRate }
        return atMaxRate.min { lhs, rhs in
            let lhsPixels = Int(lhs.dimensions.width) * Int(lhs.dimensions.height)
            let rhsPixels = Int(rhs.dimensions.width) * Int(rhs.dimensions.height)
            return lhsPixels < rhsPixels
        }
    }
}
