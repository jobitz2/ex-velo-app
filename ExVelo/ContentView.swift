import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var captureController = CaptureSessionController()
    @StateObject private var analysisCoordinator = SwingAnalysisCoordinator()
    @State private var lastClipURL: URL?
    @State private var isShowingReview = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CaptureView(captureController: captureController) { url in
                    lastClipURL = url
                    Task {
                        guard let geometry = captureController.activeCameraGeometry else { return }
                        await analysisCoordinator.analyze(clipAt: url, cameraGeometry: geometry)
                    }
                }
                SwingAnalysisStatusView(status: analysisCoordinator.status, metrics: analysisCoordinator.latestMetrics)
                    .padding(.top, 60)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("History") {
                        HistoryView()
                    }
                    .foregroundStyle(.white)
                }
            }
            .onChange(of: analysisCoordinator.latestMetrics) { _, metrics in
                guard let metrics else { return }
                let swing = Swing(
                    capturedAt: Date(),
                    clipURL: lastClipURL,
                    exitVelocityMph: metrics.exitVelocityMph,
                    launchAngleDegrees: metrics.launchAngleDegrees,
                    estimatedDistanceFeet: metrics.estimatedDistanceFeet,
                    calibrationMethod: analysisCoordinator.latestCalibratedTrajectories.first?.calibrationMethod ?? "unknown"
                )
                modelContext.insert(swing)
                isShowingReview = true
            }
            .sheet(isPresented: $isShowingReview) {
                if let clipURL = lastClipURL {
                    let bestTrajectory = analysisCoordinator.latestTrajectories.max { $0.detectedPoints.count < $1.detectedPoints.count }
                    ReviewView(clipURL: clipURL, trajectory: bestTrajectory, metrics: analysisCoordinator.latestMetrics)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Swing.self, inMemory: true)
}
