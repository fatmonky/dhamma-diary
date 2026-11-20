import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openReview) private var openReview

    var showOnboardingCoach: Bool = false
    var onCompleteCoach: () -> Void = {}
    var onDismissCoach: () -> Void = {}
    var onStoneSaved: () -> Void = {}
    /// True while the next mind check-in was opened from a notification.
    var mindPrompted: Binding<Bool> = .constant(false)

    @State private var addStoneType: StoneType? = nil
    @State private var currentDate = Date.now
    @State private var todayStones: [Stone] = []
    /// Tonight's question, shown in the morning card (spec 8.1).
    @State private var tonightQuestion: String?
    @State private var displayedStoneType: StoneType = .white
    @State private var flipAngle: Double = 0
    @State private var holdScale: CGFloat = 1.0
    @State private var arrowPulse: Bool = false
    @State private var coachStep: Int = 0

    // Press-and-slide mind check-in (spec 9.6).
    /// The stone has been held long enough to be either a log or a slide.
    @State private var stonePressed = false
    /// The press became a slide, so it records a check-in, not a stone.
    @State private var mindSliding = false
    @State private var mindNoise: Double = 50
    @State private var stoneOffset: CGFloat = 0
    @State private var holdToLogTask: Task<Void, Never>?
    @State private var holdToLogFired = false
    @State private var lastRecorded: MindCheck?
    @State private var recordedMessageTask: Task<Void, Never>?

    /// While sliding, the rest of Today steps back behind the noise.
    private var othersOpacity: Double { mindSliding ? 0.12 : 1 }

    /// How far up or down (in points) reaches fully noisy or fully still.
    private let slideRange: CGFloat = 170

    private func reloadTodayStones() {
        let interval = DateHelpers.reflectionDayInterval(for: currentDate)
        let predicate = #Predicate<Stone> { stone in
            stone.timestamp >= interval.start && stone.timestamp < interval.end
        }
        let descriptor = FetchDescriptor<Stone>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        todayStones = modelContext.fetchOrEmpty(descriptor)

        // The entry's stored question if one is written, as Tonight shows it.
        let day = DateHelpers.reflectionDay(for: currentDate)
        tonightQuestion = JournalStore.entry(forDay: day, in: modelContext)?.question
            ?? PassageSequence.passage(for: day)?.question
    }

    private var whiteCount: Int {
        todayStones.filter { $0.type == .white }.count
    }

    private var blackCount: Int {
        todayStones.filter { $0.type == .black }.count
    }

    private func addStone(_ type: StoneType) {
        addStoneType = type
    }

    private func flipStone(direction: CGFloat) {
        let newType: StoneType = displayedStoneType == .white ? .black : .white
        playFlipHaptic()
        withAnimation(.easeInOut(duration: 0.4)) {
            flipAngle += direction >= 0 ? 180 : -180
        }
        // Swap the displayed type at the midpoint of the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            displayedStoneType = newType
        }
    }

    private func playFlipHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            generator.impactOccurred()
        }
    }

    private var coachTitle: String {
        coachStep == 0 ? "Swipe to switch stone" : "Hold to log this stone"
    }

    private var coachMessage: String {
        coachStep == 0
            ? "Swipe left or right on the stone to switch between White and Black."
            : "Press and hold the stone for a moment to open the log sheet."
    }

    var body: some View {
        ZStack {
            NoiseBackdrop(level: mindSliding ? mindNoise / 100 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.35), value: mindSliding)

            ScrollView {
                VStack(spacing: 0) {
                    // Header: date + ratio bar
                    VStack(alignment: .leading, spacing: 12) {
                        Text(DateHelpers.fullDateString(for: DateHelpers.reflectionDay(for: currentDate)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let tonightQuestion {
                            MorningQuestionCard(question: tonightQuestion)
                        }

                        if whiteCount + blackCount > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your ratio today of good thoughts to bad thoughts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                RatioBar(white: whiteCount, black: blackCount)
                                    .frame(height: 12)
                            }
                        }

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .opacity(othersOpacity)

                    Spacer(minLength: 40)

                    // Single flippable stone: swipe to flip, hold to log,
                    // press and slide up/down for a mind check-in.
                    VStack(spacing: 12) {
                        Image(systemName: "chevron.up")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .opacity(arrowPulse ? 0.6 : 0.2)
                            .accessibilityHidden(true)

                        HStack(spacing: 24) {
                            Image(systemName: "chevron.left")
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .opacity(arrowPulse ? 0.8 : 0.3)

                            StoneIcon(type: displayedStoneType, size: 240)
                                .scaleEffect(holdScale)
                                .rotation3DEffect(
                                    .degrees(flipAngle),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                                .offset(y: stoneOffset)
                                .contentShape(Circle())
                                .gesture(stoneGesture)
                                .accessibilityElement()
                                .accessibilityLabel("\(displayedStoneType == .white ? "White" : "Black") stone")
                                .accessibilityHint("Double-tap and hold to log this stone.")
                                .accessibilityAction(named: "Flip stone") { flipStone(direction: 1) }
                                .accessibilityAction(named: "Log this stone") { addStone(displayedStoneType) }
                                .accessibilityAction(named: "Mind check-in: still") { recordMind(noise: 10) }
                                .accessibilityAction(named: "Mind check-in: in between") { recordMind(noise: 50) }
                                .accessibilityAction(named: "Mind check-in: noisy") { recordMind(noise: 90) }

                            Image(systemName: "chevron.right")
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .opacity(arrowPulse ? 0.8 : 0.3)
                        }

                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .opacity(arrowPulse ? 0.6 : 0.2)
                            .accessibilityHidden(true)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            arrowPulse = true
                        }
                    }

                    VStack(spacing: 4) {
                        Text("Swipe left/right to flip stone \u{2022} Hold to log")
                        Text("Press and slide up/down to log how noisy your mind is now.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 6)
                    .opacity(othersOpacity)

                    recordedLine
                        .frame(height: 22)
                        .padding(.top, 4)

                    // Counts, and the outline of the day's noisy–still chart.
                    HStack(spacing: 28) {
                        HStack(spacing: 6) {
                            StoneIcon(type: .white, size: 20)
                            Text("\(whiteCount)")
                                .font(.system(size: 20, weight: .light))
                        }
                        HStack(spacing: 6) {
                            StoneIcon(type: .black, size: 20)
                            Text("\(blackCount)")
                                .font(.system(size: 20, weight: .light))
                        }
                        Button {
                            openReview?()
                        } label: {
                            MindSparkline(day: DateHelpers.reflectionDay(for: currentDate))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Review")
                    }
                    .padding(.top, 10)
                    .opacity(othersOpacity)

                    Spacer(minLength: 40)

                    // Today's stones timeline
                    if !todayStones.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Today's Stones")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                            ForEach(Array(todayStones.enumerated()), id: \.element.id) { index, stone in
                                NavigationLink(value: stone.persistentModelID) {
                                    HStack(spacing: 0) {
                                        // Timeline column
                                        ZStack {
                                            if todayStones.count > 1 {
                                                VStack(spacing: 0) {
                                                    Rectangle()
                                                        .fill(index == 0 ? Color.clear : Color.gray.opacity(0.3))
                                                        .frame(width: 2)
                                                    Rectangle()
                                                        .fill(index == todayStones.count - 1 ? Color.clear : Color.gray.opacity(0.3))
                                                        .frame(width: 2)
                                                }
                                                .padding(.vertical, -6)
                                            }
                                            StoneIcon(type: stone.type, size: 28)
                                        }
                                        .frame(width: 36)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(DateHelpers.timeString(for: stone.timestamp))
                                                .font(.subheadline.weight(.medium))
                                            TodayStoneTagPills(stone: stone)
                                            if !stone.note.isEmpty {
                                                Text(stone.note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .padding(.leading, 10)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(.top, 8)
                        .opacity(othersOpacity)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: mindSliding)
                .frame(minHeight: UIScreen.main.bounds.height * 0.75)
            }
            .scrollDisabled(stonePressed)
            .allowsHitTesting(!showOnboardingCoach)

            mindWords

            if showOnboardingCoach {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    Spacer(minLength: 220)

                    VStack(spacing: 10) {
                        Text(coachTitle)
                            .font(.headline)
                        Text(coachMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        if coachStep == 0 {
                            Button("Next") {
                                coachStep = 1
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ColorHelpers.accent)
                        } else {
                            Button("Try it now") {
                                onCompleteCoach()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ColorHelpers.accent)
                        }

                        Button("Not now") {
                            onDismissCoach()
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Dhamma Diary")
                    .font(.headline)
            }
        }
        .navigationTitle("Today")
        .navigationDestination(for: PersistentIdentifier.self) { id in
            StoneDetailView(stoneID: id)
        }
        .sheet(item: $addStoneType, onDismiss: reloadTodayStones) { type in
            AddStoneSheet(
                stoneType: type,
                onSave: onStoneSaved
            )
        }
        .onAppear(perform: reloadTodayStones)
        #if DEBUG
        // For simulator screenshots: `simctl launch … -debug.mindSlide 95`
        // freezes a slide at that noise level.
        .onAppear {
            // `-debug.seedMind YES` (throwaway simulators only) adds three check-ins today.
            let today = DateHelpers.reflectionDay(for: currentDate)
            if UserDefaults.standard.bool(forKey: "debug.seedMind"),
               MindCheckStore.checks(onDay: today, in: modelContext).isEmpty {
                for (hour, minute, noise) in [(9, 40, 82.0), (14, 10, 18.0), (19, 25, 47.0)] {
                    let time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
                    modelContext.insert(MindCheck(timestamp: time, noise: noise, prompted: true))
                }
                try? modelContext.save()
            }
            if let value = UserDefaults.standard.string(forKey: "debug.mindSlide").flatMap(Double.init) {
                stonePressed = true
                mindSliding = true
                mindNoise = value
                stoneOffset = CGFloat(50 - value) / 50 * 44
            }
        }
        #endif
        .onChange(of: showOnboardingCoach) { _, isVisible in
            if isVisible {
                coachStep = 0
            }
        }
        .onChange(of: currentDate) { _, _ in
            reloadTodayStones()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                currentDate = .now
                reloadTodayStones()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            currentDate = .now
            reloadTodayStones()
        }
        .task(id: DateHelpers.reflectionDayKey(for: currentDate)) {
            // Move to the next reflection day at 03:00 while the screen is open.
            let end = DateHelpers.reflectionDayInterval(for: currentDate).end
            let seconds = max(end.timeIntervalSinceNow, 0) + 1
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            currentDate = .now
        }
    }
}

// MARK: - Press and slide: mind check-in (spec 9.6)

extension TodayView {
    /// Hold still for a moment, then either keep holding (log a stone, as
    /// before) or slide up/down (a mind check-in). A quick swipe left or
    /// right fails the hold and flips the stone instead.
    var stoneGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !stonePressed {
                    beginPress()
                }
                if let drag {
                    slide(drag.translation.height)
                }
            }
            .onEnded { _ in
                endPress()
            }
            .exclusively(before: flipGesture)
    }

    private var flipGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    flipStone(direction: value.translation.width)
                }
            }
    }

    private func beginPress() {
        stonePressed = true
        holdToLogFired = false
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeInOut(duration: 0.6)) {
            holdScale = 1.1
        }
        // Held still for 0.8s in all: log a stone, as before.
        holdToLogTask?.cancel()
        holdToLogTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, !mindSliding else { return }
            holdToLogFired = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) {
                holdScale = 1.0
            }
            addStone(displayedStoneType)
        }
    }

    private func slide(_ dy: CGFloat) {
        guard !holdToLogFired else { return }
        if !mindSliding {
            guard abs(dy) > 10 else { return }
            holdToLogTask?.cancel()
            mindSliding = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) {
                holdScale = 1.0
            }
        }
        let previousWord = MindDaySummary.word(for: mindNoise)
        // Up is noisy, down is still; the press starts in between.
        mindNoise = MindDaySummary.noise(forSlide: Double(dy), range: Double(slideRange))
        stoneOffset = min(max(dy * 0.25, -44), 44)
        if MindDaySummary.word(for: mindNoise) != previousWord {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func endPress() {
        holdToLogTask?.cancel()
        if mindSliding {
            recordMind(noise: mindNoise)
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            stoneOffset = 0
            holdScale = 1.0
        }
        stonePressed = false
        mindSliding = false
        holdToLogFired = false
        mindNoise = 50
    }

    func recordMind(noise: Double) {
        let check = MindCheck(noise: noise, prompted: mindPrompted.wrappedValue)
        modelContext.insert(check)
        try? modelContext.save()
        mindPrompted.wrappedValue = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        lastRecorded = check
        recordedMessageTask?.cancel()
        recordedMessageTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation { lastRecorded = nil }
        }
    }

    private func undoLastRecorded() {
        guard let lastRecorded else { return }
        modelContext.delete(lastRecorded)
        try? modelContext.save()
        recordedMessageTask?.cancel()
        withAnimation { self.lastRecorded = nil }
    }

    /// "Noted at 20:53: fairly noisy. Undo", for a few seconds after a check-in.
    @ViewBuilder
    var recordedLine: some View {
        if let lastRecorded, !lastRecorded.isDeleted {
            HStack(spacing: 8) {
                Text("Noted at \(DateHelpers.timeString(for: lastRecorded.timestamp)): \(MindDaySummary.word(for: lastRecorded.noise).lowercased()).")
                    .foregroundStyle(.secondary)
                Button("Undo", action: undoLastRecorded)
                    .foregroundStyle(ColorHelpers.accent)
            }
            .font(.footnote)
            .transition(.opacity)
        }
    }

    /// "Noisy Mind" near the top and "Still" near the bottom, fading in as
    /// the slide reaches either end.
    var mindWords: some View {
        let noisy = mindSliding ? min(max((mindNoise - 60) / 40, 0), 1) : 0
        let still = mindSliding ? min(max((40 - mindNoise) / 40, 0), 1) : 0
        return VStack {
            Text("Noisy Mind")
                .opacity(0.55 * noisy)
            Spacer()
            Text("Still")
                .opacity(0.55 * still)
        }
        .font(.system(size: 34, weight: .regular, design: .serif).italic())
        .foregroundStyle(.primary)
        .padding(.vertical, 40)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeOut(duration: 0.2), value: mindSliding)
    }
}

private struct TodayStoneTagPills: View {
    let stone: Stone

    var body: some View {
        HStack(spacing: 6) {
            if !stone.rootDisplayNames.isEmpty {
                tag(
                    label: stone.rootDisplayNames.count == 1 ? "root" : "roots",
                    value: stone.rootDisplayNames.joined(separator: ", ")
                )
            }
            if let intensity = stone.intensity {
                tag(label: "intensity", value: intensity.displayName)
            }
        }
        .padding(.vertical, stone.rootDisplayNames.isEmpty && stone.intensity == nil ? 0 : 2)
    }

    private func tag(label: String, value: String) -> some View {
        Text("\(label): \(value)")
            .font(.caption2.weight(.medium))
            .foregroundStyle(ColorHelpers.accent)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(ColorHelpers.accent.opacity(0.11))
            )
    }
}

/// "Carry this through the day": tonight's question, all day, on Today
/// (spec 8.1). Tapping it opens Diary → Tonight.
private struct MorningQuestionCard: View {
    @Environment(\.openDiary) private var openDiary
    let question: String

    var body: some View {
        Button {
            openDiary?(.tonight)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Carry this through the day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(question)
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens tonight's passage in the Diary")
    }
}
