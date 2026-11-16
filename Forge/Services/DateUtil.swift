import Foundation

extension Date {
    static var cal: Calendar { Calendar.current }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self }

    func addingDays(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }

    /// Calendar weekday: 1 = Sunday … 7 = Saturday
    var weekday: Int { Calendar.current.component(.weekday, from: self) }

    var dayOfYear: Int { Calendar.current.ordinality(of: .day, in: .year, for: self) ?? 1 }

    var startOfWeek: Date {
        let c = Calendar.current
        let comps = c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return c.date(from: comps)?.startOfDay ?? startOfDay
    }

    var startOfMonth: Date {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: self))?.startOfDay ?? startOfDay
    }

    /// The last `n` days ending today (oldest first).
    static func lastDays(_ n: Int, endingAt end: Date = Date()) -> [Date] {
        (0..<n).reversed().map { end.startOfDay.addingDays(-$0) }
    }

    func formatted(_ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate(pattern)
        return f.string(from: self)
    }

    var longDate: String { formatted("EEEEdMMMM") }
    var shortDate: String { formatted("dMMM") }
    var weekdayShort: String { formatted("EEE") }
    var weekdayInitial: String { String(formatted("EEEEE").prefix(1)) }
    var timeString: String { formatted("jmm") }
}

func daysBetween(_ a: Date, _ b: Date) -> Int {
    Calendar.current.dateComponents([.day], from: a.startOfDay, to: b.startOfDay).day ?? 0
}

// MARK: - Number parsing / formatting

func parseDouble(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    guard !t.isEmpty else { return nil }
    return Double(t)
}

extension Double {
    /// "72.5" or "72" – no trailing zeros.
    var clean: String {
        if self.rounded() == self { return String(Int(self)) }
        return String(format: "%.1f", self)
    }
    var oneDecimal: String { String(format: "%.1f", self) }
    var whole: String { String(Int(self.rounded())) }
}

func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

func formatMinutes(_ seconds: Int) -> String {
    let m = Int((Double(seconds) / 60).rounded())
    if m >= 60 { return "\(m / 60)h \(m % 60)m" }
    return "\(m) min"
}

struct DatedValue: Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}
