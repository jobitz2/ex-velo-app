import CoreMedia
import Foundation

/// Bridges RadarGunEngine's background frame processing to the main-actor UI
/// state SwiftUI observes. CaptureKit calls `ingest` from its background
/// sample-buffer queue; the result is hopped to the main actor here so the engine
/// itself never has to know about SwiftUI.
@MainActor
final class RadarGunCoordinator: ObservableObject {
    enum Status: Equatable {
        case scanning
        case reading(speedMph: Double)
    }

    @Published private(set) var status: Status = .scanning
    @Published private(set) var currentTrajectory: TrackedTrajectory?

    private let engine = RadarGunEngine()

    func updateGeometry(_ geometry: CameraGeometry) {
        engine.updateGeometry(geometry)
    }

    /// Safe to call from any queue — the expensive work happens synchronously on
    /// the caller's queue inside RadarGunEngine, and only the resulting UI state
    /// update is dispatched to the main actor.
    nonisolated func ingest(_ sampleBuffer: CMSampleBuffer) {
        let reading = engine.ingest(sampleBuffer)
        Task { @MainActor in
            currentTrajectory = reading.trajectory
            if let speedMph = reading.speedMph {
                status = .reading(speedMph: speedMph)
            } else if reading.trajectory == nil {
                status = .scanning
            }
        }
    }
}
