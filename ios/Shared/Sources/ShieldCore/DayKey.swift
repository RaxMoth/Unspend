import Foundation

/// Calendar helpers shared by the app and its extensions.
enum DayKey {
    /// Local calendar day of `date` as `yyyy-MM-dd`.
    ///
    /// Facts such as "the usage limit was reached" are stamped with the day
    /// they happened on, so they stop applying by themselves at midnight.
    /// The Dart side uses the same format (`lib/core/time/day_key.dart`).
    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
    }

    /// Minutes since local midnight (0...1439).
    static func minuteOfDay(for date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
