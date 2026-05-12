import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
class TimerController: ObservableObject {
    @Published var currentTimeEntry: TimeEntry?
    @Published var isRunning: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var revision: Int = 0

    var repository: EntryRepository?
    var scheduleManager: ScheduleManager?
    var alertService: AlertService?

    private var displayTimer: AnyCancellable?

    func startSession() {
        guard currentTimeEntry == nil || !isRunning else { return }

        if currentTimeEntry == nil {
            let now = Date()
            let scheduled = scheduleManager?.scheduledSeconds(for: now) ?? 0
            currentTimeEntry = TimeEntry(
                date: now,
                startTime: now,
                segments: [],
                scheduledSeconds: scheduled
            )
        }

        currentTimeEntry?.startSegment()
        isRunning = true
        startDisplayTimer()
        save()
    }

    func stopSession() {
        let lastIndex = currentTimeEntry?.segments.indices.last
        currentTimeEntry?.stopSegment()
        removeOverlappingWithLastSegment(at: lastIndex)
        isRunning = false
        stopDisplayTimer()
        tick()
        save()
    }

    func editStartTime(to newTime: Date) {
        guard var entry = currentTimeEntry else { return }
        guard let firstIndex = entry.segments.indices.first else { return }

        let cal = Calendar.current
        let newHour = cal.component(.hour, from: newTime)
        let newMinute = cal.component(.minute, from: newTime)

        let originalStart = entry.segments[firstIndex]
        let originalMinutes = originalStart.startHour * 60 + originalStart.startMinute
        let newMinutes = newHour * 60 + newMinute
        let deltaMinutes = newMinutes - originalMinutes

        var updatedSegments = entry.segments

        for i in updatedSegments.indices {
            let seg = updatedSegments[i]
            let newStartMinutes = seg.startHour * 60 + seg.startMinute + deltaMinutes
            let clampedStartMinutes = max(0, min(23 * 60 + 59, newStartMinutes))

            if let endH = seg.endHour, let endM = seg.endMinute {
                let endMinutes = endH * 60 + endM + deltaMinutes
                let clampedEndMinutes = max(0, min(23 * 60 + 59, endMinutes))
                updatedSegments[i] = WorkSegment(
                    id: seg.id,
                    date: entry.date,
                    startHour: clampedStartMinutes / 60,
                    startMinute: clampedStartMinutes % 60,
                    endHour: clampedEndMinutes / 60,
                    endMinute: clampedEndMinutes % 60,
                    project: seg.project
                )
            } else {
                updatedSegments[i] = WorkSegment(
                    id: seg.id,
                    date: entry.date,
                    startHour: clampedStartMinutes / 60,
                    startMinute: clampedStartMinutes % 60,
                    project: seg.project
                )
            }
        }

        entry.segments = updatedSegments
        currentTimeEntry = entry
        tick()
        save()
    }

    func updateProject(_ project: String) {
        guard var entry = currentTimeEntry else { return }
        entry.project = project
        currentTimeEntry = entry
        save()
    }

    func updateSegmentStart(segmentId: UUID, hour: Int, minute: Int) {
        guard var entry = currentTimeEntry else { return }
        do {
            try entry.validateAndUpdateSegmentStart(segmentId: segmentId, hour: hour, minute: minute)
            currentTimeEntry = entry
            tick()
            save()
        } catch { NSSound.beep() }
    }

    func updateSegmentEnd(segmentId: UUID, hour: Int, minute: Int) {
        guard var entry = currentTimeEntry else { return }
        do {
            try entry.validateAndUpdateSegmentEnd(segmentId: segmentId, hour: hour, minute: minute)
            currentTimeEntry = entry
            tick()
            save()
        } catch {}
    }

    func deleteSegment(segmentId: UUID) {
        guard var entry = currentTimeEntry else { return }
        entry.segments.removeAll { $0.id == segmentId }

        if entry.segments.isEmpty {
            currentTimeEntry = nil
            isRunning = false
            elapsedTime = 0
            remainingTime = scheduleManager?.scheduledSeconds(for: Date()) ?? 0
            progress = 0
            repository?.delete(entry)
            revision += 1
        } else {
            currentTimeEntry = entry
            tick()
            save()
        }
    }

    func loadToday() {
        alertService?.reset()
        let today = Calendar.current.startOfDay(for: Date())

        if let existing = repository?.getEntry(for: Date()) {
            let entryDay = Calendar.current.startOfDay(for: existing.date)

            if entryDay == today {
                currentTimeEntry = existing

                if let scheduled = scheduleManager?.scheduledSeconds(for: Date()) {
                    currentTimeEntry?.scheduledSeconds = scheduled
                }

                if existing.isActive {
                    isRunning = true
                    startDisplayTimer()
                } else {
                    isRunning = false
                    tick()
                }
            } else {
                if existing.isActive {
                    var stoppedEntry = existing
                    stoppedEntry.stopSegment()
                    repository?.save(stoppedEntry)
                }
                currentTimeEntry = nil
                isRunning = false
                elapsedTime = 0
                remainingTime = scheduleManager?.scheduledSeconds(for: Date()) ?? 0
                progress = 0
            }
        } else {
            currentTimeEntry = nil
            isRunning = false
            elapsedTime = 0
            remainingTime = scheduleManager?.scheduledSeconds(for: Date()) ?? 0
            progress = 0
        }
    }

    private func removeOverlappingWithLastSegment(at index: Array<WorkSegment>.Index?) {
        guard let idx = index, var entry = currentTimeEntry, idx < entry.segments.count else { return }
        let seg = entry.segments[idx]
        guard let eh = seg.endHour, let em = seg.endMinute else { return }
        entry.removeSegmentsOverlapping(startHour: seg.startHour, startMinute: seg.startMinute, endHour: eh, endMinute: em, excluding: seg.id)
        currentTimeEntry = entry
    }

    private func startDisplayTimer() {
        stopDisplayTimer()
        displayTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        tick()
    }

    private func stopDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    private func tick() {
        if let entry = currentTimeEntry {
            let today = Calendar.current.startOfDay(for: Date())
            let entryDay = Calendar.current.startOfDay(for: entry.date)

            if entryDay != today {
                if entry.isActive {
                    var stopped = entry
                    stopped.stopSegment()
                    repository?.save(stopped)
                } else {
                    repository?.save(entry)
                }

                let dayScheduled = scheduleManager?.scheduledSeconds(for: Date()) ?? 0

                if isRunning {
                    let now = Date()
                    var newEntry = TimeEntry(
                        date: now,
                        startTime: now,
                        segments: [],
                        scheduledSeconds: dayScheduled,
                        project: entry.project
                    )
                    newEntry.startSegment()
                    currentTimeEntry = newEntry
                    alertService?.reset()
                    save()
                } else {
                    currentTimeEntry = nil
                    revision += 1
                }

                elapsedTime = 0
                remainingTime = dayScheduled
                progress = 0
                return
            }
        }

        guard let entry = currentTimeEntry else {
            elapsedTime = 0
            remainingTime = 0
            progress = 0
            return
        }

        elapsedTime = entry.totalWorkedSeconds
        remainingTime = entry.scheduledSeconds - elapsedTime
        progress = entry.progress

        if let config = scheduleManager?.config {
            alertService?.check(entry: entry, elapsed: elapsedTime, config: config)
        }
    }

    private func save() {
        guard let entry = currentTimeEntry else { return }
        repository?.save(entry)
        revision += 1
    }

    // MARK: - Week Summary

    func currentWeekEntries() -> [TimeEntry] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }
        return repository?.loadAll().filter { entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            return entryDay >= weekInterval.start && entryDay < weekInterval.end
        } ?? []
    }

    func weekTotalWorked() -> TimeInterval {
        currentWeekEntries().reduce(0) { $0 + $1.totalWorkedSeconds }
    }

    func weekTotalScheduled() -> TimeInterval {
        currentWeekEntries().reduce(0) { $0 + $1.scheduledSeconds }
    }
}
