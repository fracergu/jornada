import Foundation
import SwiftUI

@MainActor
class ScheduleManager: ObservableObject {
    @Published var config: ScheduleConfig

    private let configKey = "JornadaScheduleConfig"

    init() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(ScheduleConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = ScheduleConfig.defaultConfig()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    func scheduledHours(for date: Date) -> Double {
        config.scheduledHours(for: date)
    }

    func scheduledSeconds(for date: Date) -> TimeInterval {
        scheduledHours(for: date) * 3600
    }

    func setHours(_ hours: Double, for weekday: Int) {
        objectWillChange.send()
        if let index = config.rules.firstIndex(where: { $0.weekday == weekday }) {
            config.rules[index].hoursPerDay = hours
        } else {
            config.rules.append(ScheduleRule(weekday: weekday, hoursPerDay: hours))
        }
        save()
    }

    func setHoursMinutes(hours: Int, minutes: Int, for weekday: Int) {
        let totalHours = Double(hours) + Double(minutes) / 60.0
        setHours(totalHours, for: weekday)
    }

    func getHoursMinutes(for weekday: Int) -> (hours: Int, minutes: Int) {
        let hoursDecimal = config.rules.first(where: { $0.weekday == weekday })?.hoursPerDay ?? 0
        let hours = Int(hoursDecimal)
        let minutes = Int((hoursDecimal - Double(hours)) * 60)
        return (hours, minutes)
    }

    func expectedEndTime(elapsed: TimeInterval, for date: Date = Date()) -> Date? {
        let remaining = scheduledSeconds(for: date) - elapsed
        guard remaining > 0 else { return nil }
        return Date().addingTimeInterval(remaining)
    }

    var alertThresholdSeconds: TimeInterval {
        TimeInterval(config.alertMinutesBeforeEnd * 60)
    }
}
