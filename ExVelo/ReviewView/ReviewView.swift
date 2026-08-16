import SwiftUI
import AVKit

/// Plays back a recorded swing with its tracked trajectory and computed metrics
/// overlaid, per docs/CLI_PROMPT.md step 7. The overlay is a static composite of
/// every detected point rather than an animation synced to playback time — full
/// sync is a V1 item (docs/ASSESSMENT.md milestone table).
struct ReviewView: View {
    let clipURL: URL
    let trajectory: TrackedTrajectory?
    let metrics: SwingMetrics?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                if let player {
                    VideoPlayer(player: player)
                        .overlay {
                            TrajectoryOverlayView(trajectory: trajectory)
                        }
                        .onAppear { player.play() }
                }

                if let metrics {
                    VStack(spacing: 2) {
                        Text("\(metrics.exitVelocityMph, specifier: "%.1f") mph \u{00b7} \(metrics.launchAngleDegrees, specifier: "%.0f")\u{00b0} \u{00b7} \(metrics.estimatedDistanceFeet, specifier: "%.0f") ft")
                            .font(.title3.weight(.semibold))
                        Text("Camera-based estimate, not radar-grade")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                player = AVPlayer(url: clipURL)
            }
        }
    }
}
