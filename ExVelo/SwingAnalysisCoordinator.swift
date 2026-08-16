import Foundation

/// Glues the pipeline stages together: a captured clip goes in, tracked and
/// calibrated trajectories come out. PhysicsEngine and SwingStore stages get added
/// here as they're built, without CaptureKit or the UI needing to change.
@MainActor
final class SwingAnalysisCoordinator: ObservableObject {
    enum Status: Equatable {
        case idle
        case analyzing
        case tracked(trajectoryCount: Int, pointCount: Int, calibrated: Bool)
        case noTrajectoryDetected
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var latestTrajectories: [TrackedTrajectory] = []
    @Published private(set) var latestCalibratedTrajectories: [CalibratedTrajectory] = []
    @Published private(set) var latestMetrics: SwingMetrics?

    private let tracker = TrajectoryTracker()
    private let calibrationEngine = CalibrationEngine.default

    func analyze(
        clipAt url: URL,
        cameraGeometry: CameraGeometry,
        guidedPlacement: GuidedPlacement? = nil,
        deviceLevelPitchDegrees: Double = 0
    ) async {
        status = .analyzing
        latestMetrics = nil
        do {
            let trajectories = try await tracker.detectTrajectories(in: url)
            latestTrajectories = trajectories
            guard !trajectories.isEmpty else {
                latestCalibratedTrajectories = []
                status = .noTrajectoryDetected
                return
            }

            let context = CalibrationContext(
                frameWidthPixels: cameraGeometry.pixelWidth,
                frameHeightPixels: cameraGeometry.pixelHeight,
                horizontalFieldOfViewDegrees: cameraGeometry.horizontalFieldOfViewDegrees,
                guidedPlacement: guidedPlacement
            )
            let calibrated = trajectories.compactMap { calibrationEngine.calibrate(trajectory: $0, context: context) }
            latestCalibratedTrajectories = calibrated

            // The longest tracked trajectory is the likeliest candidate for the
            // actual ball; shorter ones are more often background clutter.
            if let best = calibrated.max(by: { $0.points.count < $1.points.count }) {
                latestMetrics = PhysicsEngine.computeMetrics(from: best, deviceLevelPitchDegrees: deviceLevelPitchDegrees)
            }

            let pointCount = trajectories.reduce(0) { $0 + $1.detectedPoints.count }
            status = .tracked(trajectoryCount: trajectories.count, pointCount: pointCount, calibrated: !calibrated.isEmpty)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
