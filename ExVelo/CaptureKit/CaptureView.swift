import SwiftUI

struct CaptureView: View {
    @StateObject private var captureController = CaptureSessionController()
    @StateObject private var levelProvider = LevelProvider()

    var onClipCaptured: (URL) -> Void = { _ in }

    var body: some View {
        ZStack {
            CameraPreviewView(session: captureController.session)
                .ignoresSafeArea()

            FramingGuideView()

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

                Button {
                    captureController.lockExposureAndFocus()
                    Task {
                        if let url = await captureController.markHit() {
                            onClipCaptured(url)
                        }
                    }
                } label: {
                    Text(captureController.isMarkingHit ? "Saving\u{2026}" : "Mark Hit")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(captureController.isMarkingHit || !captureController.isRunning)
                .padding()
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
            await captureController.requestAccessAndConfigure()
            captureController.start()
            levelProvider.start()
        }
        .onDisappear {
            captureController.stop()
            levelProvider.stop()
        }
    }
}

#Preview {
    CaptureView()
}
