import SwiftUI
import SwiftData

enum OnboardingStep: String {
    case welcome
    case todayCoach
    case firstLog
    case reviewTour
    case diaryTour
    case completed

    /// The step to use when the app appears or the stone count changes.
    /// - Completed stays completed, even after every stone is deleted.
    /// - Fresh users with no stones start at welcome.
    /// - Existing users with stones skip onboarding, unless they're part way
    ///   through the steps that follow the first stone.
    static func bootstrapped(
        from current: OnboardingStep?,
        hasStones: Bool,
        showingPostFirstEntry: Bool
    ) -> OnboardingStep {
        if current == .completed {
            return .completed
        }
        if !hasStones {
            return current ?? .welcome
        }
        switch current {
        case .firstLog, .reviewTour, .diaryTour:
            return current!
        default:
            return showingPostFirstEntry ? (current ?? .completed) : .completed
        }
    }
}

struct ContentView: View {
    @Query private var allStones: [Stone]

    @State private var selectedTab = 0
    @State private var showWelcome = false
    @State private var showPostFirstEntry = false
    /// Where the Diary tab should open next, set from Today, Review or the widget.
    @State private var diaryRequest: DiaryDestination?

    @AppStorage("onboarding.step") private var onboardingStepRaw = ""

    private var onboardingStep: OnboardingStep? {
        get { OnboardingStep(rawValue: onboardingStepRaw) }
        nonmutating set { onboardingStepRaw = newValue?.rawValue ?? "" }
    }

    private var isFreshUser: Bool {
        allStones.isEmpty
    }

    private var shouldShowWelcomeSheet: Bool {
        isFreshUser && onboardingStep == .welcome
    }

    private var shouldShowTodayCoach: Bool {
        isFreshUser && onboardingStep == .todayCoach && selectedTab == 0
    }

    private var shouldShowReviewTour: Bool {
        onboardingStep == .reviewTour && selectedTab == 1
    }

    private var shouldShowDiaryTour: Bool {
        onboardingStep == .diaryTour && selectedTab == 2
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(
                    showOnboardingCoach: shouldShowTodayCoach,
                    onCompleteCoach: {
                        onboardingStep = .firstLog
                    },
                    onDismissCoach: {
                        finishOnboarding()
                    },
                    onStoneSaved: {
                        guard onboardingStep == .firstLog else { return }
                        showPostFirstEntry = true
                    }
                )
            }
            .tabItem { Label("Today", systemImage: "circle.fill") }
            .tag(0)

            NavigationStack {
                ReviewView(
                    showTourOverlay: shouldShowReviewTour,
                    onFinishTour: {
                        onboardingStep = .diaryTour
                        selectedTab = 2
                    },
                    onSkipTour: finishOnboarding
                )
            }
            .tabItem { Label("Review", systemImage: "calendar") }
            .tag(1)

            NavigationStack {
                DiaryView(
                    request: $diaryRequest,
                    showTourOverlay: shouldShowDiaryTour,
                    onFinishTour: finishOnboarding,
                    onSkipTour: finishOnboarding
                )
            }
            .tabItem { Label("Diary", systemImage: "text.book.closed") }
            .tag(2)

            NavigationStack {
                AboutView()
            }
            .tabItem { Label("About", systemImage: "info.circle") }
            .tag(3)
        }
        .tint(ColorHelpers.accent)
        .environment(\.openDiary) { destination in
            diaryRequest = destination
            selectedTab = 2
        }
        .onAppear {
            bootstrapOnboardingState()
            syncTabWithOnboardingStep()
            #if DEBUG
            // For simulator screenshots: `simctl launch … -debug.selectedTab 2`.
            if let tab = UserDefaults.standard.string(forKey: "debug.selectedTab").flatMap(Int.init) {
                selectedTab = tab
            }
            #endif
        }
        .onChange(of: allStones.count) { _, _ in
            bootstrapOnboardingState()
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeOnboardingSheet(
                onStart: {
                    showWelcome = false
                    onboardingStep = .todayCoach
                    selectedTab = 0
                },
                onSkip: {
                    showWelcome = false
                    finishOnboarding()
                }
            )
        }
        .sheet(isPresented: $showPostFirstEntry) {
            FirstStoneSuccessSheet(
                onContinue: {
                    showPostFirstEntry = false
                    onboardingStep = .reviewTour
                    selectedTab = 1
                },
                onSkip: {
                    showPostFirstEntry = false
                    finishOnboarding()
                }
            )
        }
    }

    private func bootstrapOnboardingState() {
        let step = OnboardingStep.bootstrapped(
            from: onboardingStep,
            hasStones: !isFreshUser,
            showingPostFirstEntry: showPostFirstEntry
        )
        if step != onboardingStep {
            onboardingStep = step
        }
        showWelcome = shouldShowWelcomeSheet
        if step == .completed {
            showPostFirstEntry = false
        }
    }

    private func syncTabWithOnboardingStep() {
        switch onboardingStep {
        case .reviewTour:
            selectedTab = 1
        case .diaryTour:
            selectedTab = 2
        default:
            break
        }
    }

    private func finishOnboarding() {
        onboardingStep = .completed
        showPostFirstEntry = false
    }
}

private struct WelcomeOnboardingSheet: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Image(systemName: "circle.inset.filled")
                    .font(.system(size: 42))
                    .foregroundStyle(ColorHelpers.accent)

                Text("A passage, a question, and your day.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Each day, the Diary tab offers a short sutta passage and one question to reflect on. During the day, you can log a white stone for a wholesome thought, or a black stone for an unskillful one. Start by logging one stone today, then take a short tour of Review and Diary.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer()

                Button("Start Tour") {
                    onStart()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorHelpers.accent)
                .controlSize(.large)

                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(24)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}

private struct FirstStoneSuccessSheet: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)

                Text("Great. You’ve started today’s record.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Next, take a quick look at Review, then finish with Diary for today's passage and question.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer()

                Button("Continue Tour") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorHelpers.accent)
                .controlSize(.large)

                Button("Finish Without Tour") {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(24)
            .navigationTitle("Nice Start")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
