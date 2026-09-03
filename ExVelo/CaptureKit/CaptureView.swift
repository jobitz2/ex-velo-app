import SwiftUI

struct CaptureView: View {
    @ObservedObject var captureController: CaptureSessionController
    @ObservedObject var radarGun: RadarGunCoordinator
    @StateObject private var levelProvider = LevelProvider()

    var body: some View {
        ZStack {
            CameraPreviewView(session: captureController.session)
                .ignoresSafeArea()

            FramingGuideView()

            TrajectoryOverlayView(trajectory: radarGun.currentTrajectory)

            VStack {
                if let warning = captureController.frameRateWarning {
                    Text(warning)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                Spacer()

                RadarReadoutView(status: radarGun.status)

                HStack {
                    LevelIndicatorView(pitchDegrees: levelProvider.pitchDegrees, rollDegrees: levelProvider.rollDegrees)
                    Spacer()
                    if captureController.achievedFrameRate > 0 {
                        Text("\(Int(captureController.achievedFrameRate)) fps")
                            .font(.caption.monospacedDigit())
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding()

                Text("This is a camera-based estimate, not a radar-grade reading.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }

            if let error = captureController.captureError {
                VStack {
                    Spacer()
                    Text(error)
                        .padding()
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                        .padding()
                }
            }
        }
        .task {
            captureController.onSampleBuffer = { [weak radarGun] buffer in
                radarGun?.ingest(buffer)
            }
            await captureController.requestAccessAndConfigure()
            captureController.start()
            levelProvider.start()
        }
        .onChange(of: captureController.activeCameraGeometry) { _, geometry in
            guard let geometry else { return }
            radarGun.updateGeometry(geometry)
        }
        .onDisappear {
            captureController.stop()
            levelProvider.stop()
        }
    }
}

#Preview {
    CaptureView(captureController: CaptureSessionController(), radarGun: RadarGunCoordinator())
}
