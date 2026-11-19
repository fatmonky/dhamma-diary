import SwiftUI
import SwiftData
import WidgetKit

enum OnboardingStep: String {
    case welcome
    case todayCoach
    case firstLog
    case reviewTour
    case diaryTour
    /// Asks once whether to turn on mind check-ins (spec 9.2).
    case mindInvite
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
        case .firstLog, .reviewTour, .diaryTour, .mindInvite:
            return current!
        default:
            return showingPostFirstEntry ? (current ?? .completed) : .completed
        }
    }
}

struct ContentView: View {
    @Query private var allStones: [Stone]
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @State private var showWelcome = false
    @State private var showPostFirstEntry = false
    /// Where the Diary tab should open next, set from Today, Review or the widget.
    @State private var diaryRequest: DiaryDestination?
    /// True while the Mind tab's check-in was opened from a notification.
    @State private var mindOpenedFromNotification = false
    @State private var mindRouter = MindCheckRouter.shared

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
                    onFinishTour: {
                        onboardingStep = .mindInvite
                    },
                    onSkipTour: finishOnboarding
                )
            }
            .tabItem { Label("Diary", systemImage: "text.book.closed") }
            .tag(2)

            NavigationStack {
                MindView(openedFromNotification: $mindOpenedFromNotification)
            }
            .tabItem { Label("Mind", systemImage: "waveform") }
            .tag(3)

            NavigationStack {
                AboutView()
            }
            .tabItem { Label("About", systemImage: "info.circle") }
            .tag(4)
        }
        .tint(ColorHelpers.accent)
        .environment(\.openDiary) { destination in
            diaryRequest = destination
            selectedTab = 2
        }
        .environment(\.openMind) {
            selectedTab = 3
        }
        // The widget opens dhammadiary://tonight (spec 8.4).
        .onOpenURL { url in
            guard url.scheme == "dhammadiary", url.host == "tonight" else { return }
            diaryRequest = .tonight
            selectedTab = 2
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WidgetCenter.shared.reloadAllTimelines()
                Task { await MindCheckNotifications.topUp() }
            }
        }
        .onChange(of: mindRouter.openRequested) { _, _ in
            openMindFromNotification()
        }
        .onAppear {
            bootstrapOnboardingState()
            syncTabWithOnboardingStep()
            openMindFromNotification()
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
        .sheet(isPresented: Binding(
            get: { onboardingStep == .mindInvite },
            set: { if !$0 { finishOnboarding() } }
        )) {
            MindInviteSheet(
                onTurnOn: {
                    finishOnboarding()
                    Task { await MindCheckNotifications.start() }
                },
                onNotNow: finishOnboarding
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

    /// A tapped check-in notification opens the Mind tab, also on a cold launch.
    private func openMindFromNotification() {
        guard mindRouter.openRequested else { return }
        mindRouter.openRequested = false
        mindOpenedFromNotification = true
        selectedTab = 3
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

private struct MindInviteSheet: View {
    let onTurnOn: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Image(systemName: "waveform")
                    .font(.system(size: 42))
                    .foregroundStyle(ColorHelpers.accent)

                Text("How noisy is your mind now?")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Three times a day, at a random moment between 9am and 9pm, Dhamma Diary can ask you this. You answer with one slide, from still to noisy. At night, the Mind tab shows how the day went. You can turn this off at any time in the Mind tab.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer()

                Button("Turn On Check-ins") {
                    onTurnOn()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorHelpers.accent)
                .controlSize(.large)

                Button("Not Now") {
                    onNotNow()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(24)
            .navigationTitle("Check-ins")
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
