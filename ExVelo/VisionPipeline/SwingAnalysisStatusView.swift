import SwiftUI

/// Debug readout confirming VNDetectTrajectoriesRequest found a plausible ball path
/// before wiring CalibrationEngine/PhysicsEngine on top of it.
struct SwingAnalysisStatusView: View {
    let status: SwingAnalysisCoordinator.Status
    var metrics: SwingMetrics?

    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()
            case .analyzing:
                label("Analyzing swing\u{2026}", systemImage: "hourglass")
            case let .tracked(trajectoryCount, pointCount, calibrated):
                if let metrics, calibrated {
                    metricsLabel(metrics)
                } else {
                    label(
                        "Tracked \(trajectoryCount) trajectory\(trajectoryCount == 1 ? "" : "ies") (\(pointCount) points)"
                            + (calibrated ? "" : " \u{2014} calibration failed"),
                        systemImage: calibrated ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                }
            case .noTrajectoryDetected:
                label("No trajectory detected \u{2014} check lighting, background clutter, and framing.", systemImage: "exclamationmark.triangle.fill")
            case let .failed(message):
                label("Analysis failed: \(message)", systemImage: "xmark.octagon.fill")
            }
        }
    }

    private func metricsLabel(_ metrics: SwingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(metrics.exitVelocityMph, specifier: "%.1f") mph \u{00b7} \(metrics.launchAngleDegrees, specifier: "%.0f")\u{00b0} \u{00b7} \(metrics.estimatedDistanceFeet, specifier: "%.0f") ft (est.)")
                .font(.subheadline.weight(.semibold))
            Text("Camera-based estimate, not radar-grade")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func label(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
