import SwiftUI
import SwiftData

/// The Diary tab (spec 4.2): Tonight (the default) and Passages (history).
struct DiaryView: View {
    /// Set from outside (Review) to open Passages at that passage.
    @Binding var passageRequest: String?
    var showTourOverlay: Bool = false
    var onFinishTour: () -> Void = {}
    var onSkipTour: () -> Void = {}

    @State private var mode: DiaryMode = .tonight
    @State private var expandedPassageID: String?
    @State private var draft = ""

    var body: some View {
        ZStack {
            Group {
                switch mode {
                case .tonight:
                    TonightView(
                        onOpenPassageHistory: { passageID in
                            expandedPassageID = passageID
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = .passages
                            }
                        },
                        text: $draft
                    )
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
        .onAppear(perform: handlePassageRequest)
        .onChange(of: passageRequest) { _, _ in
            handlePassageRequest()
        }
        #if DEBUG
        // For simulator screenshots: `simctl launch … -debug.diaryMode passages`.
        .onAppear {
            if UserDefaults.standard.string(forKey: "debug.diaryMode") == "passages" {
                mode = .passages
            }
        }
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = mode == .tonight ? .passages : .tonight
                    }
                } label: {
                    Text(mode == .tonight ? "Passages" : "Tonight")
                }
                // Tour overlays block the screen underneath, toolbar included.
                .disabled(showTourOverlay)
            }
        }
    }

    private func handlePassageRequest() {
        guard let passageID = passageRequest else { return }
        passageRequest = nil
        expandedPassageID = passageID
        mode = .passages
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

private enum DiaryMode {
    case tonight
    case passages
}
