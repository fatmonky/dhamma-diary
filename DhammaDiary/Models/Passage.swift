import Foundation
import OSLog

/// The passage details a new journal entry keeps a copy of.
struct JournalPassageCopy: Equatable {
    var passageID: String
    var passageRef: String
    var passageTitle: String
    var question: String
}

/// One bundled passage (spec 3.3). Read-only; never stored in SwiftData.
struct Passage: Codable, Identifiable, Equatable {
    struct SegmentRange: Codable, Equatable {
        let start: String
        let end: String
    }

    /// Permanent; never reused, kept when the question is reworded.
    let id: String
    let ref: String
    let title: String
    let uid: String
    let ranges: [SegmentRange]
    /// One block per range; each block is its segments in order.
    let blocks: [[String]]
    /// A few segments from inside `blocks`, short enough for the passage widget.
    let excerpt: [String]
    let question: String
    let url: URL

    /// What a journal entry keeps a copy of.
    var journalCopy: JournalPassageCopy {
        JournalPassageCopy(passageID: id, passageRef: ref, passageTitle: title, question: question)
    }
}

/// The bundled `passages.json`. File order is sequence order.
struct PassageSet: Codable, Equatable {
    struct Source: Codable, Equatable {
        let repo: String
        let branch: String
        let commit: String
        let translator: String
    }

    let formatVersion: Int
    let source: Source
    let passages: [Passage]

    enum LoadError: Error {
        case missingFile
    }

    private static let logger = Logger(subsystem: "com.whitestone.DhammaDiary", category: "passages")

    /// Loaded once. An unreadable file is a build error, so it's logged and
    /// the set is empty rather than crashing on launch.
    static let bundled: PassageSet = {
        do {
            return try load(from: .main)
        } catch {
            logger.error("Could not load passages.json: \(String(describing: error))")
            return PassageSet(
                formatVersion: 1,
                source: Source(repo: "", branch: "", commit: "", translator: ""),
                passages: []
            )
        }
    }()

    static func load(from bundle: Bundle) throws -> PassageSet {
        guard let url = bundle.url(forResource: "passages", withExtension: "json") else {
            throw LoadError.missingFile
        }
        return try JSONDecoder().decode(PassageSet.self, from: Data(contentsOf: url))
    }

    func passage(withID id: String) -> Passage? {
        passages.first { $0.id == id }
    }
}
