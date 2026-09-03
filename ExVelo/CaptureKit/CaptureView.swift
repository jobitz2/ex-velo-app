import SwiftUI

struct CaptureView: View {
    @ObservedObject var captureController: CaptureSessionController
    @ObservedObject var radarGun: RadarGunCoordinator

    var body: some View {
        ZStack {
            CameraPreviewView(session: captureController.session)
                .ignoresSafeArea()

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

                if captureController.achievedFrameRate > 0 {
                    Text("\(Int(captureController.achievedFrameRate)) fps")
                        .font(.caption.monospacedDigit())
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding()
                }

                Text("This is a camera-based estimate, not a radar-grade reading.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                scanButton
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
        }
        .onChange(of: captureController.activeCameraGeometry) { _, geometry in
            guard let geometry else { return }
            radarGun.updateGeometry(geometry)
        }
        .onDisappear {
            captureController.stop()
        }
    }

    /// Press-and-hold trigger: frames are only tracked while this is held down,
    /// like a real radar gun's trigger, rather than continuously scanning
    /// whatever the camera happens to be pointed at.
    private var scanButton: some View {
        Text(radarGun.isScanning ? "Scanning…" : "Hold to Scan")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                radarGun.isScanning ? Color.red : Color.accentColor,
                in: RoundedRectangle(cornerRadius: 18)
            )
            .padding(.horizontal)
            .padding(.bottom, 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in radarGun.startScanning() }
                    .onEnded { _ in radarGun.stopScanning() }
            )
    }
}

#Preview {
    CaptureView(captureController: CaptureSessionController(), radarGun: RadarGunCoordinator())
}
