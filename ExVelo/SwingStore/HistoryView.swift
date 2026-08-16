import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Swing.capturedAt, order: .reverse) private var swings: [Swing]

    var body: some View {
        Group {
            if swings.isEmpty {
                ContentUnavailableView(
                    "No Swings Yet",
                    systemImage: "baseball",
                    description: Text("Mark a hit while recording to save your first swing.")
                )
            } else {
                List(swings) { swing in
                    SwingRow(swing: swing)
                }
            }
        }
        .navigationTitle("History")
    }
}

private struct SwingRow: View {
    let swing: Swing

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(swing.exitVelocityMph, specifier: "%.1f") mph \u{00b7} \(swing.launchAngleDegrees, specifier: "%.0f")\u{00b0} \u{00b7} \(swing.estimatedDistanceFeet, specifier: "%.0f") ft")
                .font(.headline)
            Text(swing.capturedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: Swing.self, inMemory: true)
}
