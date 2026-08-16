import SwiftUI

struct ContentView: View {
    @StateObject private var captureController = CaptureSessionController()
    @StateObject private var analysisCoordinator = SwingAnalysisCoordinator()

    var body: some View {
        ZStack(alignment: .top) {
            CaptureView(captureController: captureController) { url in
                Task {
                    guard let geometry = captureController.activeCameraGeometry else { return }
                    await analysisCoordinator.analyze(clipAt: url, cameraGeometry: geometry)
                }
            }
            SwingAnalysisStatusView(status: analysisCoordinator.status)
                .padding(.top, 60)
        }
    }
}

#Preview {
    ContentView()
}
