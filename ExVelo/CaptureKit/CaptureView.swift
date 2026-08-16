import SwiftUI

struct CaptureView: View {
    @ObservedObject var captureController: CaptureSessionController
    @StateObject private var levelProvider = LevelProvider()

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
                    if captureController.isSessionActive {
                        Text("\(captureController.sessionSwingCount) swing\(captureController.sessionSwingCount == 1 ? "" : "s")")
                            .font(.caption.monospacedDigit())
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
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
                    Task {
                        if captureController.isSessionActive {
                            captureController.stopSession()
                        } else {
                            _ = await captureController.startSession()
                        }
                    }
                } label: {
                    Text(captureController.isSessionActive ? "Stop Session" : "Start Session")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            captureController.isSessionActive ? Color.red : Color.green,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundStyle(.white)
                }
                .disabled(!captureController.isRunning)
                .padding(.horizontal)

                Text(captureController.isSessionActive
                    ? "Auto-detecting each swing from the crack of the bat \u{2014} just keep swinging."
                    : "Start a session, then just swing \u{2014} each hit is detected automatically.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)

                Button {
                    Task { _ = await captureController.markHit() }
                } label: {
                    Text(captureController.isMarkingHit ? "Saving\u{2026}" : "Mark Hit Manually")
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .disabled(captureController.isMarkingHit || !captureController.isRunning)
                .padding(.horizontal)
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
            await captureController.requestAccessAndConfigure()
            captureController.start()
            levelProvider.start()
        }
        .onDisappear {
            captureController.stopSession()
            captureController.stop()
            levelProvider.stop()
        }
    }
}

#Preview {
    CaptureView(captureController: CaptureSessionController())
}
