import Foundation
import Testing
@testable import Jornada

// MARK: - WorkSegment Tests

@Test func workSegmentActiveDuration() {
    let now = Date()
    let cal = Calendar.current
    let segment = WorkSegment(
        date: now,
        startHour: cal.component(.hour, from: now),
        startMinute: cal.component(.minute, from: now)
    )
    #expect(!segment.isCompleted)
    #expect(segment.duration >= 0)
}

@Test func workSegmentCompletedDuration() {
    let cal = Calendar.current
    let date = cal.startOfDay(for: Date())
    let segment = WorkSegment(
        date: date,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0
    )
    #expect(segment.isCompleted)
    #expect(segment.duration == 8 * 3600)
}

@Test func workSegmentMidnightCrossing() {
    let cal = Calendar.current
    let date = cal.startOfDay(for: Date())
    let segment = WorkSegment(
        date: date,
        startHour: 23,
        startMinute: 0,
        endHour: 1,
        endMinute: 0
    )
    #expect(segment.isCompleted)
    #expect(segment.duration == 2 * 3600)
}

@Test func workSegmentInvalidStartAfterEnd() {
    let cal = Calendar.current
    let segment = WorkSegment(
        date: cal.startOfDay(for: Date()),
        startHour: 10,
        startMinute: 0,
        endHour: 9,
        endMinute: 0
    )
    #expect(segment.duration >= 0)
}

// MARK: - TimeEntry Tests

@Test func timeEntryTotalWorkedSeconds() {
    let cal = Calendar.current
    let date = cal.startOfDay(for: Date())
    let segments = [
        WorkSegment(date: date, startHour: 9, startMinute: 0, endHour: 13, endMinute: 0),
        WorkSegment(date: date, startHour: 14, startMinute: 0, endHour: 18, endMinute: 0)
    ]
    let entry = TimeEntry(segments: segments)
    #expect(entry.totalWorkedSeconds == 8 * 3600)
}

@Test func timeEntryProgress() {
    let cal = Calendar.current
    let date = cal.startOfDay(for: Date())
    let segments = [
        WorkSegment(date: date, startHour: 9, startMinute: 0, endHour: 13, endMinute: 0)
    ]
    let entry = TimeEntry(segments: segments, scheduledSeconds: 8 * 3600)
    #expect(abs(entry.progress - 0.5) < 0.001)
}

@Test func timeEntryHasOverlap() {
    let cal = Calendar.current
    let date = cal.startOfDay(for: Date())
    let segments = [
        WorkSegment(date: date, startHour: 9, startMinute: 0, endHour: 13, endMinute: 0)
    ]
    let entry = TimeEntry(segments: segments)
    #expect(entry.hasOverlap(startHour: 10, startMinute: 0, endHour: 14, endMinute: 0))
    #expect(!entry.hasOverlap(startHour: 14, startMinute: 0, endHour: 18, endMinute: 0))
}

// MARK: - ScheduleConfig Tests

@Test func scheduleConfigDefaultHours() {
    let config = ScheduleConfig.defaultConfig()
    let cal = Calendar.current
    let monday = dateWith(weekday: 2, in: cal)
    let tuesday = dateWith(weekday: 3, in: cal)
    let sunday = dateWith(weekday: 1, in: cal)

    #expect(config.scheduledHours(for: monday) == 8)
    #expect(config.scheduledHours(for: tuesday) == 8)
    #expect(config.scheduledHours(for: sunday) == 0)
}

private func dateWith(weekday: Int, in cal: Calendar) -> Date {
    let today = Date()
    let todayWeekday = cal.component(.weekday, from: today)
    let diff = weekday - todayWeekday
    return cal.date(byAdding: .day, value: diff, to: today) ?? today
}

// MARK: - EntryRepository Tests

@MainActor
@Test func repositorySaveAndLoad() {
    let repo = MockEntryRepository()
    let entry = TimeEntry(segments: [])
    repo.save(entry)
    let loaded = repo.loadAll()
    #expect(loaded.count == 1)
    #expect(loaded[0].id == entry.id)
}

@MainActor
@Test func repositoryDelete() {
    let repo = MockEntryRepository()
    let entry = TimeEntry(segments: [])
    repo.save(entry)
    repo.delete(entry)
    #expect(repo.loadAll().isEmpty)
}

@MainActor
@Test func repositoryDeleteAll() {
    let repo = MockEntryRepository()
    repo.save(TimeEntry(segments: []))
    repo.save(TimeEntry(segments: []))
    repo.deleteAll()
    #expect(repo.loadAll().isEmpty)
}
