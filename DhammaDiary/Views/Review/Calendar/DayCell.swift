import SwiftUI

struct DayCell: View {
    let day: Int
    let ratio: Double?
    var hasEntry: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorHelpers.color(forRatio: ratio))
            Text("\(day)")
                .font(.caption)
                .foregroundStyle(ratio != nil ? (ratio! > 0.5 ? .black : .white) : .primary)

            if hasEntry {
                Circle()
                    .fill(ColorHelpers.accent)
                    .frame(width: 5, height: 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(5)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
