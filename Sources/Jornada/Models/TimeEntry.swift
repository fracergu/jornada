import Foundation

struct WorkSegment: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var startHour: Int
    var startMinute: Int
    var endHour: Int?
    var endMinute: Int?
    var project: String

    init(
        id: UUID = UUID(),
        date: Date = Calendar.current.startOfDay(for: Date()),
        startHour: Int,
        startMinute: Int,
        endHour: Int? = nil,
        endMinute: Int? = nil,
        project: String = ""
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.project = project
    }

    private var startDate: Date {
        Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date) ?? date
    }

    private var resolvedEndDate: Date? {
        guard let eh = endHour, let em = endMinute else { return nil }
        var d = Calendar.current.date(bySettingHour: eh, minute: em, second: 0, of: date) ?? date
        if d <= startDate {
            d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return d
    }

    var duration: TimeInterval {
        if let end = resolvedEndDate {
            return end.timeIntervalSince(startDate)
        }
        return Date().timeIntervalSince(startDate)
    }

    var isCompleted: Bool {
        endHour != nil && endMinute != nil
    }

    var isValid: Bool {
        guard let end = resolvedEndDate else { return true }
        return end > startDate
    }

    enum CodingKeys: String, CodingKey {
        case id, date, startHour, startMinute, endHour, endMinute, project
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Calendar.current.startOfDay(for: Date())
        startHour = try container.decode(Int.self, forKey: .startHour)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endHour = try container.decodeIfPresent(Int.self, forKey: .endHour)
        endMinute = try container.decodeIfPresent(Int.self, forKey: .endMinute)
        project = try container.decodeIfPresent(String.self, forKey: .project) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(startHour, forKey: .startHour)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encodeIfPresent(endHour, forKey: .endHour)
        try container.encodeIfPresent(endMinute, forKey: .endMinute)
        try container.encode(project, forKey: .project)
    }
}

struct TimeEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var startTime: Date
    var segments: [WorkSegment]
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

    // MARK: - Validation

    enum SegmentEditError: Error, Equatable {
        case endBeforeStart
        case overlapsExisting
        case segmentNotFound
    }

    mutating func validateAndUpdateSegmentStart(segmentId: UUID, hour: Int, minute: Int) throws {
        guard let index = segments.firstIndex(where: { $0.id == segmentId }) else {
            throw SegmentEditError.segmentNotFound
        }
        let segment = segments[index]
        if segment.isCompleted {
            guard let endH = segment.endHour, let endM = segment.endMinute else { return }
            guard (hour * 60 + minute) < (endH * 60 + endM) else { throw SegmentEditError.endBeforeStart }
            guard !hasOverlap(startHour: hour, startMinute: minute, endHour: endH, endMinute: endM, excludingSegmentId: segment.id) else { throw SegmentEditError.overlapsExisting }
        } else {
            guard !hasOverlap(startHour: hour, startMinute: minute, endHour: 23, endMinute: 59, excludingSegmentId: segment.id) else { throw SegmentEditError.overlapsExisting }
        }
        segments[index] = WorkSegment(
            id: segment.id,
            date: segment.date,
            startHour: hour,
            startMinute: minute,
            endHour: segment.endHour,
            endMinute: segment.endMinute,
            project: segment.project
        )
    }

    mutating func validateAndUpdateSegmentEnd(segmentId: UUID, hour: Int, minute: Int) throws {
        guard let index = segments.firstIndex(where: { $0.id == segmentId }) else {
            throw SegmentEditError.segmentNotFound
        }
        let segment = segments[index]
        guard segment.isCompleted else { return }
        guard (hour * 60 + minute) > (segment.startHour * 60 + segment.startMinute) else { throw SegmentEditError.endBeforeStart }
        guard !hasOverlap(startHour: segment.startHour, startMinute: segment.startMinute, endHour: hour, endMinute: minute, excludingSegmentId: segment.id) else { throw SegmentEditError.overlapsExisting }
        segments[index] = WorkSegment(
            id: segment.id,
            date: segment.date,
            startHour: segment.startHour,
            startMinute: segment.startMinute,
            endHour: hour,
            endMinute: minute,
            project: segment.project
        )
    }

    mutating func startSegment() {
        if !isActive {
            let now = Date()
            let cal = Calendar.current
            segments.append(WorkSegment(
                date: date,
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
