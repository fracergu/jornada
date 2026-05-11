import Foundation

struct ScheduleRule: Codable, Identifiable {
    var id: Int { weekday }
    let weekday: Int
    var hoursPerDay: Double
}

class ScheduleConfig: ObservableObject, Codable {
    @Published var rules: [ScheduleRule]
    @Published var alertMinutesBeforeEnd: Int
    @Published var alertSoundEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case rules, alertMinutesBeforeEnd, alertSoundEnabled
    }

    init(
        rules: [ScheduleRule] = ScheduleConfig.defaultRules,
        alertMinutesBeforeEnd: Int = 10,
        alertSoundEnabled: Bool = true
    ) {
        self.rules = rules
        self.alertMinutesBeforeEnd = alertMinutesBeforeEnd
        self.alertSoundEnabled = alertSoundEnabled
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rules = try container.decode([ScheduleRule].self, forKey: .rules)
        alertMinutesBeforeEnd = try container.decode(Int.self, forKey: .alertMinutesBeforeEnd)
        alertSoundEnabled = try container.decode(Bool.self, forKey: .alertSoundEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rules, forKey: .rules)
        try container.encode(alertMinutesBeforeEnd, forKey: .alertMinutesBeforeEnd)
        try container.encode(alertSoundEnabled, forKey: .alertSoundEnabled)
    }

    func scheduledHours(for date: Date) -> Double {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return rules.first(where: { $0.weekday == weekday })?.hoursPerDay ?? 0
    }

    func scheduledSeconds(for date: Date) -> TimeInterval {
        scheduledHours(for: date) * 3600
    }

    static let defaultRules: [ScheduleRule] = [
        ScheduleRule(weekday: 2, hoursPerDay: 8.0),
        ScheduleRule(weekday: 3, hoursPerDay: 8.0),
        ScheduleRule(weekday: 4, hoursPerDay: 8.0),
        ScheduleRule(weekday: 5, hoursPerDay: 8.0),
        ScheduleRule(weekday: 6, hoursPerDay: 8.0),
        ScheduleRule(weekday: 7, hoursPerDay: 0),
        ScheduleRule(weekday: 1, hoursPerDay: 0),
    ]

    static func defaultConfig() -> ScheduleConfig {
        ScheduleConfig()
    }

    static let weekdayNames: [Int: String] = [
        1: "Sunday",
        2: "Monday",
        3: "Tuesday",
        4: "Wednesday",
        5: "Thursday",
        6: "Friday",
        7: "Saturday",
    ]

    static func weekdayName(for weekday: Int) -> String {
        weekdayNames[weekday] ?? ""
    }
}
