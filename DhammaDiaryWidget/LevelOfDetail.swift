import SwiftUI
import WidgetKit

/// Whether the system asks for a simplified widget (iOS 26 `levelOfDetail`),
/// for example when it is shown at a glance, as on a CarPlay screen
/// (spec 9.11, experimental). Always false before iOS 26.
struct SimplifiedReader<Content: View>: View {
    @ViewBuilder let content: (_ simplified: Bool) -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            Reader26(content: content)
        } else {
            content(false)
        }
    }
}

@available(iOS 26.0, *)
private struct Reader26<Content: View>: View {
    @Environment(\.levelOfDetail) private var levelOfDetail
    let content: (Bool) -> Content

    var body: some View {
        content(levelOfDetail == .simplified)
    }
}
