import SwiftUI
import SwiftData

/// The Diary tab (spec 4.2): Tonight (the default), Entries (every entry by
/// date) and Passages (every passage and its question), chosen at the top.
struct DiaryView: View {
    /// Set from outside (Today, Review, the widget) to open a destination.
    @Binding var request: DiaryDestination?
    var showTourOverlay: Bool = false
    var onFinishTour: () -> Void = {}
    var onSkipTour: () -> Void = {}

    @State private var mode: DiaryMode = .tonight
    @State private var expandedPassageID: String?
    @State private var draft = TonightDraft()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Picker("Diary", selection: $mode.animation(.easeInOut(duration: 0.2))) {
                    ForEach(DiaryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch mode {
                case .tonight:
                    TonightView(
                        onOpenPassageHistory: { passageID in
                            expandedPassageID = passageID
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = .passages
                            }
                        },
                        draft: $draft
                    )
                case .entries:
                    EntriesView()
                case .passages:
                    PassagesView(expandedPassageID: $expandedPassageID)
                }
            }
            .allowsHitTesting(!showTourOverlay)

            if showTourOverlay {
                tourOverlay
            }
        }
        .navigationTitle("Diary")
        .onAppear(perform: handleRequest)
        .onChange(of: request) { _, _ in
            handleRequest()
        }
        #if DEBUG
        // For simulator screenshots: `simctl launch … -debug.diaryMode entries` (or passages).
        .onAppear {
            if let raw = UserDefaults.standard.string(forKey: "debug.diaryMode"),
               let debugMode = DiaryMode(rawValue: raw) {
                mode = debugMode
            }
        }
        #endif
    }

    private func handleRequest() {
        guard let destination = request else { return }
        request = nil
        switch destination {
        case .tonight:
            mode = .tonight
        case .passage(let passageID):
            expandedPassageID = passageID
            mode = .passages
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

                    Text("Each day brings a new passage and one question. Write as much or as little as you like, or nothing at all. An entry written before 3am counts for the day before. Past entries are kept by date in Entries, and every passage and question is in Passages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Finish Tour") {
                        onFinishTour()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorHelpers.accent)

                    Button("Skip Tour") {
                        onSkipTour()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.tertiarySystemBackground)) // white in light mode, dark grey in dark mode
                )
                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                Spacer()
            }
        }
    }
}

private enum DiaryMode: String, CaseIterable, Identifiable {
    case tonight
    case entries
    case passages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tonight: "Tonight"
        case .entries: "Entries"
        case .passages: "Passages"
        }
    }
}
