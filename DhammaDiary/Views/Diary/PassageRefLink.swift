import SwiftUI

/// "AN 10.61 · Ignorance ↗", opening the sutta on SuttaCentral. An entry
/// whose passage is no longer bundled shows the same line as plain text.
struct PassageRefLink: View {
    let passageID: String
    let ref: String
    let title: String
    var font: Font = .footnote

    private var url: URL? {
        PassageSet.bundled.passage(withID: passageID)?.url
    }

    var body: some View {
        if let url {
            Link(destination: url) {
                Label("\(ref) · \(title)", systemImage: "arrow.up.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .font(font)
                    .foregroundStyle(ColorHelpers.accent)
            }
            .buttonStyle(.borderless)
            .accessibilityHint("Opens the full sutta on SuttaCentral")
        } else {
            Text("\(ref) · \(title)")
                .font(font)
                .foregroundStyle(.secondary)
        }
    }
}
