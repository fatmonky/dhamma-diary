import Foundation

enum ReflectionDateFormatters {
    static let saveTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()

    static let detailTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()
}
