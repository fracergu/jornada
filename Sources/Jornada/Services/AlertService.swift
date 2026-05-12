import Foundation
import AppKit

@MainActor
final class AlertService {
    private var alertFiredToday: Bool = false
    private var lastAlertDate: Date = .distantPast

    func reset() {
        alertFiredToday = false
        lastAlertDate = .distantPast
    }

    func check(entry: TimeEntry, elapsed: TimeInterval, config: ScheduleConfig) {
        guard config.alertSoundEnabled else { return }

        let threshold = TimeInterval(config.alertMinutesBeforeEnd) * 60
        let remaining = entry.scheduledSeconds - elapsed

        let now = Date()
        if !Calendar.current.isDate(lastAlertDate, inSameDayAs: now) {
            alertFiredToday = false
        }

        if remaining <= threshold && remaining > threshold - 2 && !alertFiredToday {
            alertFiredToday = true
            lastAlertDate = now
            if let sound = NSSound(named: .init("Glass")) {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }
}
