import AppIntents
import Foundation

// Siri and Shortcuts (spec 9.11): log a stone, note the mind, or hear
// tonight's question without looking at the screen, including in CarPlay.
// Logs go through the same queue as the widgets; the app imports it the next
// time it becomes active.

enum StoneColor: String, AppEnum {
    case white, black

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Stone"
    static let caseDisplayRepresentations: [StoneColor: DisplayRepresentation] = [
        .white: "white",
        .black: "black",
    ]
}

enum MindNoise: String, AppEnum {
    case noisy, inBetween, still

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Mind"
    static let caseDisplayRepresentations: [MindNoise: DisplayRepresentation] = [
        .noisy: DisplayRepresentation(title: "noisy", synonyms: ["busy", "loud"]),
        .inBetween: DisplayRepresentation(title: "in between", synonyms: ["so-so", "somewhere in between"]),
        .still: DisplayRepresentation(title: "still", synonyms: ["quiet", "calm"]),
    ]

    /// The same values as the widget buttons.
    var noise: Double {
        switch self {
        case .noisy: 90
        case .inBetween: 50
        case .still: 10
        }
    }
}

struct VoiceLogStoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Stone"
    static let description = IntentDescription("Logs a white or black stone for today.")

    @Parameter(title: "Stone")
    var stone: StoneColor

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$stone) stone")
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WidgetLogQueue.append(WidgetLog(kind: stone == .white ? .whiteStone : .blackStone, timestamp: .now))
        return .result(dialog: "Logged a \(stone == .white ? "white" : "black") stone.")
    }
}

struct VoiceNoteMindIntent: AppIntent {
    static let title: LocalizedStringResource = "Note How Noisy My Mind Is"
    static let description = IntentDescription("Notes whether your mind is noisy, in between or still right now.")

    @Parameter(title: "Mind", requestValueDialog: "How noisy is your mind now? Noisy, in between, or still?")
    var mind: MindNoise

    static var parameterSummary: some ParameterSummary {
        Summary("My mind is \(\.$mind)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WidgetLogQueue.append(WidgetLog(kind: .mind, timestamp: .now, noise: mind.noise))
        return .result(dialog: "Noted.")
    }
}

struct TonightQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Tonight's Question"
    static let description = IntentDescription("Reads tonight's question, to carry through the day.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let passage = PassageSequence.passage() else {
            return .result(dialog: "Tonight's passage couldn't be loaded.")
        }
        return .result(dialog: "\(passage.question)")
    }
}

struct DhammaDiaryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VoiceLogStoneIntent(),
            phrases: [
                "Log a \(\.$stone) stone in \(.applicationName)",
                "Add a \(\.$stone) stone in \(.applicationName)",
                "\(.applicationName) \(\.$stone) stone",
            ],
            shortTitle: "Log a Stone",
            systemImageName: "circle.lefthalf.filled"
        )
        AppShortcut(
            intent: VoiceNoteMindIntent(),
            phrases: [
                "My mind is \(\.$mind) in \(.applicationName)",
                "Note my mind in \(.applicationName)",
                "\(.applicationName) check-in",
            ],
            shortTitle: "Note My Mind",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: TonightQuestionIntent(),
            phrases: [
                "What's tonight's question in \(.applicationName)",
                "Tonight's question in \(.applicationName)",
                "\(.applicationName) question",
            ],
            shortTitle: "Tonight's Question",
            systemImageName: "text.book.closed"
        )
    }
}
