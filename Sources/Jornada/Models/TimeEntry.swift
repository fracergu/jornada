import Foundation

struct WorkSegment: Codable, Identifiable, Equatable {
    let id: UUID
    var startHour: Int      // 0-23
    var startMinute: Int    // 0-59
    var endHour: Int?       // nil = activo
    var endMinute: Int?     // nil = activo
    var project: String

    init(id: UUID = UUID(), startHour: Int, startMinute: Int, endHour: Int? = nil, endMinute: Int? = nil, project: String = "") {
        self.id = id
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.project = project
    }

    // Duration calculada desde hour/minute
    var duration: TimeInterval {
        let now = Date()
        let cal = Calendar.current
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let startMinutes = startHour * 60 + startMinute
        guard startMinutes < nowMinutes else { return 0 }

        guard let eh = endHour, let em = endMinute else {
            let nowS = cal.component(.second, from: now)
            return TimeInterval((nowMinutes * 60 + nowS) - (startMinutes * 60))
        }
        return TimeInterval((eh * 60 + em) - (startMinutes))
    }

    var isCompleted: Bool {
        endHour != nil && endMinute != nil
    }

    // Convertir a Date para DatePicker bindings
    func startDate(on date: Date) -> Date {
        Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date) ?? date
    }

    func endDate(on date: Date) -> Date? {
        guard let eh = endHour, let em = endMinute else { return nil }
        return Calendar.current.date(bySettingHour: eh, minute: em, second: 0, of: date) ?? date
    }

    // Crear desde DatePicker
    static func fromStart(_ date: Date) -> WorkSegment {
        let cal = Calendar.current
        return WorkSegment(
            startHour: cal.component(.hour, from: date),
            startMinute: cal.component(.minute, from: date)
        )
    }

    // Validar que end > start
    var isValid: Bool {
        guard let eh = endHour, let em = endMinute else { return true }
        return (eh * 60 + em) > (startHour * 60 + startMinute)
    }
}

struct TimeEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date                // Normalizado a startOfDay, solo para day-bucket
    var startTime: Date           // Timestamp del primer inicio (para referencia)
    var segments: [WorkSegment]   // Tiempos como hour/minute
    var scheduledSeconds: TimeInterval
    var notes: String
    var project: String

    init(
        id: UUID = UUID(),
        date: Date = Calendar.current.startOfDay(for: Date()),
        startTime: Date = Date(),
        segments: [WorkSegment] = [],
        scheduledSeconds: TimeInterval = 0,
        notes: String = "",
        project: String = ""
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.startTime = startTime
        self.segments = segments
        self.scheduledSeconds = scheduledSeconds
        self.notes = notes
        self.project = project
    }

    var isActive: Bool {
        guard let last = segments.last else { return false }
        return last.endHour == nil
    }

    var totalWorkedSeconds: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    var progress: Double {
        guard scheduledSeconds > 0 else { return 0 }
        return min(totalWorkedSeconds / scheduledSeconds, 1.0)
    }

    func formattedDuration() -> String {
        let total = Int(totalWorkedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func hasOverlap(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, excludingSegmentId: UUID? = nil) -> Bool {
        let startMins = startHour * 60 + startMinute
        let endMins = endHour * 60 + endMinute
        for seg in segments {
            if let exId = excludingSegmentId, seg.id == exId { continue }
            guard let eh = seg.endHour, let em = seg.endMinute else { continue }
            let segStart = seg.startHour * 60 + seg.startMinute
            let segEnd = eh * 60 + em
            if startMins < segEnd && segStart < endMins { return true }
        }
        return false
    }

    mutating func removeSegmentsOverlapping(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, excluding segmentId: UUID) {
        let rangeStart = startHour * 60 + startMinute
        let rangeEnd = endHour * 60 + endMinute
        segments.removeAll { seg in
            guard seg.id != segmentId else { return false }
            guard let eh = seg.endHour, let em = seg.endMinute else { return false }
            let segStart = seg.startHour * 60 + seg.startMinute
            let segEnd = eh * 60 + em
            return segStart < rangeEnd && rangeStart < segEnd
        }
    }

    mutating func startSegment() {
        if !isActive {
            let now = Date()
            let cal = Calendar.current
            segments.append(WorkSegment(
                startHour: cal.component(.hour, from: now),
                startMinute: cal.component(.minute, from: now)
            ))
        }
    }

    mutating func stopSegment() {
        guard let lastIndex = segments.indices.last,
              segments[lastIndex].endHour == nil else { return }
        let now = Date()
        let cal = Calendar.current
        segments[lastIndex].endHour = cal.component(.hour, from: now)
        segments[lastIndex].endMinute = cal.component(.minute, from: now)
    }
}
