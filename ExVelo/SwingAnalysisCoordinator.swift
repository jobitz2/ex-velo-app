import Foundation

/// Glues the pipeline stages together: a captured clip goes in, tracked trajectory
/// points come out. CalibrationEngine and PhysicsEngine stages get added here as
/// they're built, without CaptureKit or the UI needing to change.
@MainActor
final class SwingAnalysisCoordinator: ObservableObject {
    enum Status: Equatable {
        case idle
        case analyzing
        case tracked(trajectoryCount: Int, pointCount: Int)
        case noTrajectoryDetected
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var latestTrajectories: [TrackedTrajectory] = []

    private let tracker = TrajectoryTracker()

    func analyze(clipAt url: URL) async {
        status = .analyzing
        do {
            let trajectories = try await tracker.detectTrajectories(in: url)
            latestTrajectories = trajectories
            if trajectories.isEmpty {
                status = .noTrajectoryDetected
            } else {
                let pointCount = trajectories.reduce(0) { $0 + $1.detectedPoints.count }
                status = .tracked(trajectoryCount: trajectories.count, pointCount: pointCount)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
