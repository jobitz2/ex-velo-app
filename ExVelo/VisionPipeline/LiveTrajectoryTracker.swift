import AVFoundation
import Vision

/// Runs VNDetectTrajectoriesRequest continuously over live camera frames, reusing
/// the same request instance across frames so Vision can keep accumulating evidence
/// for a parabolic path instead of re-detecting it from scratch each frame — the
/// same technique docs/ASSESSMENT.md describes for a recorded clip, applied live so
/// a reading is available the moment a ball's path is tracked instead of after the
/// fact. Not thread-safe on its own: every call must come from the same serial
/// queue (the capture session's sample-buffer queue), which is what makes the
/// unsynchronized dictionary access below safe.
final class LiveTrajectoryTracker {
    struct Configuration {
        /// Minimum points needed to fit a parabola. Vision requires at least 5.
        var trajectoryLength: Int = 10
    }

    /// A trajectory plus a per-point apparent ball radius (pixels), measured
    /// independently of Vision's own trajectory-wide average (see
    /// BallRadiusEstimator) so calibration can derive a per-point depth instead
    /// of one shared depth for the whole trajectory. Parallel to
    /// `trajectory.detectedPoints`; may be shorter if some frames' measurements
    /// were inconclusive — KnownObjectSizeCalibration falls back to the
    /// trajectory-wide average for any point missing a measurement.
    struct Tracked {
        let trajectory: TrackedTrajectory
        let radiusPixels: [CGFloat]
    }

    private let configuration: Configuration
    private var latestByID: [UUID: TrackedTrajectory] = [:]
    private var radiusHistoryByID: [UUID: [CGFloat]] = [:]

    private lazy var request: VNDetectTrajectoriesRequest = {
        VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: configuration.trajectoryLength) { [weak self] request, error in
            guard error == nil, let observations = request.results as? [VNTrajectoryObservation] else { return }
            for observation in observations {
                self?.latestByID[observation.uuid] = TrackedTrajectory(observation: observation)
            }
        }
    }()

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Feeds one live frame into the ongoing trajectory request and returns every
    /// trajectory tracked so far, each with its per-point radius history.
    /// VNDetectTrajectoriesRequest's completion handler runs synchronously within
    /// `perform`, so `latestByID` is already up to date by the time this returns.
    func process(sampleBuffer: CMSampleBuffer) -> [Tracked] {
        let countsBefore = latestByID.mapValues { $0.detectedPoints.count }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        try? handler.perform([request])

        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let frameWidthPixels = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            for (id, trajectory) in latestByID {
                let pointCount = trajectory.detectedPoints.count
                // A trajectory whose point count didn't grow this frame has
                // nothing new for this frame's pixel buffer to measure —
                // Vision refined an existing point rather than adding one, or
                // this id belongs to a different trajectory that didn't update.
                guard pointCount > (countsBefore[id] ?? 0), let newest = trajectory.detectedPoints.last else { continue }

                let hintRadiusPixels = trajectory.averageRadius * frameWidthPixels
                let measured = BallRadiusEstimator.estimateRadiusPixels(
                    pixelBuffer: pixelBuffer,
                    normalizedPoint: newest.normalizedLocation,
                    hintRadiusPixels: hintRadiusPixels
                )

                var history = radiusHistoryByID[id] ?? []
                // Vision can occasionally report more than one new point in a
                // single callback; padding with this frame's measurement keeps
                // the history aligned with detectedPoints without re-running
                // the estimator more than once per callback.
                let value = measured ?? hintRadiusPixels
                while history.count < pointCount {
                    history.append(value)
                }
                radiusHistoryByID[id] = history
            }
        }

        return latestByID.map { id, trajectory in
            Tracked(trajectory: trajectory, radiusPixels: radiusHistoryByID[id] ?? [])
        }
    }

    /// Clears tracked state so the next ball through the frame starts a fresh
    /// trajectory instead of blending with a stale one.
    func reset() {
        latestByID.removeAll()
        radiusHistoryByID.removeAll()
    }
}
