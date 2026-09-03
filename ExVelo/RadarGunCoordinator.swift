import CoreMedia
import Foundation

/// Bridges RadarGunEngine's background frame processing to the main-actor UI
/// state SwiftUI observes. CaptureKit calls `ingest` from its background
/// sample-buffer queue for every captured frame; the result is hopped to the
/// main actor here so the engine itself never has to know about SwiftUI.
///
/// Frames are only actually processed while a scan is held — like a real radar
/// gun's trigger — both so an idle phone doesn't burn battery running Vision on
/// every frame, and so pointing the camera around doesn't produce readings
/// nobody asked for.
@MainActor
final class RadarGunCoordinator: ObservableObject {
    enum Status: Equatable {
        case idle
        case scanning
        case reading(speedMph: Double)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var isScanning = false
    @Published private(set) var currentTrajectory: TrackedTrajectory?

    private let engine = RadarGunEngine()
    /// Cheap gate read from the nonisolated `ingest` on the sample-buffer queue;
    /// `isScanning` above is the `@Published` twin that drives UI. Both are only
    /// ever written from the main actor (SwiftUI's gesture handlers), so there's
    /// no write-write race — `nonisolated(unsafe)` just lets the background
    /// queue read it without an actor hop on every frame.
    nonisolated(unsafe) private var scanningFlag = false

    func updateGeometry(_ geometry: CameraGeometry) {
        engine.updateGeometry(geometry)
    }

    /// Call when the scan button is pressed. Safe to call repeatedly while held.
    func startScanning() {
        guard !isScanning else { return }
        engine.reset()
        currentTrajectory = nil
        status = .scanning
        isScanning = true
        scanningFlag = true
    }

    /// Call when the scan button is released. Any speed already read stays on
    /// screen until the next press; if nothing was tracked this hold, the
    /// readout reverts to idle instead of staying stuck on "scanning."
    func stopScanning() {
        guard isScanning else { return }
        isScanning = false
        scanningFlag = false
        if status == .scanning {
            status = .idle
        }
    }

    /// Safe to call from any queue — the expensive work happens synchronously on
    /// the caller's queue inside RadarGunEngine, and only the resulting UI state
    /// update is dispatched to the main actor.
    nonisolated func ingest(_ sampleBuffer: CMSampleBuffer) {
        guard scanningFlag else { return }
        let reading = engine.ingest(sampleBuffer)
        Task { @MainActor in
            currentTrajectory = reading.trajectory
            if let speedMph = reading.speedMph {
                status = .reading(speedMph: speedMph)
            } else if reading.trajectory == nil, status == .scanning {
                status = .scanning
            }
        }
    }
}
