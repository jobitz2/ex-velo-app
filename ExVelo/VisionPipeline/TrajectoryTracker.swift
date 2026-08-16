import AVFoundation
import Vision

/// Runs VNDetectTrajectoriesRequest over every frame of a recorded clip, reusing
/// the same request instance across frames so Vision can accumulate evidence for
/// the parabolic path instead of re-detecting from scratch each frame. This is the
/// MVP starting point instead of a custom-trained ball detector (see docs/ASSESSMENT.md).
final class TrajectoryTracker {
    struct Configuration {
        /// kCMTimeZero processes every frame; nonzero throttles analysis on slower devices.
        var frameAnalysisSpacing: CMTime = .zero
        /// Minimum points needed to fit a parabola. Vision requires at least 5.
        var trajectoryLength: Int = 10
        /// Normalized bounding-circle radius bounds used to filter out noise/large objects.
        var objectMinimumNormalizedRadius: Float?
        var objectMaximumNormalizedRadius: Float?
    }

    enum TrackerError: Error {
        case noVideoTrack
        case readerFailed
    }

    private let configuration: Configuration

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    func detectTrajectories(in url: URL) async throws -> [TrackedTrajectory] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw TrackerError.noVideoTrack
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false
        reader.add(trackOutput)

        // VNDetectTrajectoriesRequest is stateful: its completion handler reports the
        // cumulative set of observations known so far, keyed by a stable uuid per
        // trajectory. Keeping the latest observation per id gives the final refined
        // path once every frame has been processed.
        var latestByID: [UUID: TrackedTrajectory] = [:]
        let request = VNDetectTrajectoriesRequest(
            frameAnalysisSpacing: configuration.frameAnalysisSpacing,
            trajectoryLength: configuration.trajectoryLength
        ) { request, error in
            guard error == nil, let observations = request.results as? [VNTrajectoryObservation] else { return }
            for observation in observations {
                latestByID[observation.uuid] = TrackedTrajectory(observation: observation)
            }
        }
        if let minimum = configuration.objectMinimumNormalizedRadius {
            request.objectMinimumNormalizedRadius = minimum
        }
        if let maximum = configuration.objectMaximumNormalizedRadius {
            request.objectMaximumNormalizedRadius = maximum
        }

        guard reader.startReading() else {
            throw reader.error ?? TrackerError.readerFailed
        }

        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
            try handler.perform([request])
        }

        if reader.status == .failed {
            throw reader.error ?? TrackerError.readerFailed
        }

        return Array(latestByID.values)
    }
}
