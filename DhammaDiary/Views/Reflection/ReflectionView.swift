import SwiftUI
import SwiftData

struct ReflectionView: View {
    var showTourOverlay: Bool = false
    var onFinishTour: () -> Void = {}
    var onSkipTour: () -> Void = {}

    @State private var mode: ReflectionMode = .today
    @State private var expandedPassageID: String?

    var body: some View {
        ZStack {
            Group {
                switch mode {
                case .today:
                    ReflectionTodayView()
                case .byQuestion:
                    ByQuestionView(expandedPassageID: $expandedPassageID)
                }
            }
            .allowsHitTesting(!showTourOverlay)

            if showTourOverlay {
                tourOverlay
            }
        }
        .navigationTitle("Diary")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = mode == .today ? .byQuestion : .today
                    }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: mode == .today ? "questionmark.bubble" : "square.and.pencil")
                            .font(.title3)
                        Text(mode == .today ? "Passages" : "Tonight")
                            .font(.caption2)
                    }
                }
                .accessibilityLabel(mode == .today ? "Passages View" : "Tonight View")
            }
        }
    }

    private var tourOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 180)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Diary")
                        .font(.headline)

                    Text("Each day brings a new passage and one question. Write as much or as little as you like, or nothing at all. An entry written before 3am counts for the day before. Past entries are kept by day and by passage in Passages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Finish Tour") {
                        onFinishTour()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.53, green: 0.38, blue: 0.22))

                    Button("Skip Tour") {
                        onSkipTour()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.98))
                )
                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                Spacer()
            }
        }
    }
}

private enum ReflectionMode {
    case today
    case byQuestion
}
