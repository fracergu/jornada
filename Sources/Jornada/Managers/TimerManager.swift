import Foundation
import SwiftUI
import Combine

@MainActor
class TimerManager: ObservableObject {
    @Published var currentTimeEntry: TimeEntry?
    @Published var isRunning: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var revision: Int = 0

    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    var scheduleManager: ScheduleManager?

    private var alertFiredToday: Bool = false

    // MARK: - Timer Control

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

    func pauseSession() {
        guard isRunning else { return }
        let lastIndex = currentTimeEntry?.segments.indices.last
        currentTimeEntry?.stopSegment()
        removeOverlappingWithLastSegment(at: lastIndex)
        isRunning = false
        stopDisplayTimer()
        tick()
        save()
    }

    func resumeSession() {
        guard !isRunning, currentTimeEntry != nil else { return }
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
                    startHour: clampedStartMinutes / 60,
                    startMinute: clampedStartMinutes % 60,
                    endHour: clampedEndMinutes / 60,
                    endMinute: clampedEndMinutes % 60,
                    project: seg.project
                )
            } else {
                updatedSegments[i] = WorkSegment(
                    id: seg.id,
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

    // MARK: - Segment Editing

    func updateSegmentStart(segmentId: UUID, hour: Int, minute: Int) {
        guard var entry = currentTimeEntry else { return }
        guard let index = entry.segments.firstIndex(where: { $0.id == segmentId }) else { return }

        let segment = entry.segments[index]

        if segment.isCompleted {
            guard let endH = segment.endHour, let endM = segment.endMinute else { return }
            guard (hour * 60 + minute) < (endH * 60 + endM) else { return }
            guard !entry.hasOverlap(startHour: hour, startMinute: minute, endHour: endH, endMinute: endM, excludingSegmentId: segment.id) else { return }
        } else {
            guard !entry.hasOverlap(startHour: hour, startMinute: minute, endHour: 23, endMinute: 59, excludingSegmentId: segment.id) else { return }
        }

        entry.segments[index] = WorkSegment(
            id: segment.id,
            startHour: hour,
            startMinute: minute,
            endHour: segment.endHour,
            endMinute: segment.endMinute,
            project: segment.project
        )
        currentTimeEntry = entry
        tick()
        save()
    }

    func updateSegmentEnd(segmentId: UUID, hour: Int, minute: Int) {
        guard var entry = currentTimeEntry else { return }
        guard let index = entry.segments.firstIndex(where: { $0.id == segmentId }) else { return }

        let segment = entry.segments[index]
        guard segment.isCompleted else { return }
        guard (hour * 60 + minute) > (segment.startHour * 60 + segment.startMinute) else { return }
        guard !entry.hasOverlap(startHour: segment.startHour, startMinute: segment.startMinute, endHour: hour, endMinute: minute, excludingSegmentId: segment.id) else { return }

        entry.segments[index] = WorkSegment(
            id: segment.id,
            startHour: segment.startHour,
            startMinute: segment.startMinute,
            endHour: hour,
            endMinute: minute,
            project: segment.project
        )
        currentTimeEntry = entry
        tick()
        save()
    }

    func deleteSegment(segmentId: UUID) {
        guard var entry = currentTimeEntry else { return }
        entry.segments.removeAll { $0.id == segmentId }

        // Fix delete bug: if no segments left, remove the entry entirely
        if entry.segments.isEmpty {
            currentTimeEntry = nil
            isRunning = false
            elapsedTime = 0
            remainingTime = scheduleManager?.scheduledSeconds(for: Date()) ?? 0
            progress = 0
            StorageService.shared.delete(entry)
            revision += 1
        } else {
            currentTimeEntry = entry
            tick()
            save()
        }
    }

    func updateSegmentStartForEntry(entryId: UUID, segmentId: UUID, hour: Int, minute: Int) {
        var entries = StorageService.shared.loadAll()
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }
        guard let segIndex = entries[entryIndex].segments.firstIndex(where: { $0.id == segmentId }) else { return }

        let segment = entries[entryIndex].segments[segIndex]
        let entry = entries[entryIndex]

        if segment.isCompleted {
            guard let endH = segment.endHour, let endM = segment.endMinute else { return }
            guard (hour * 60 + minute) < (endH * 60 + endM) else { return }
            guard !entry.hasOverlap(startHour: hour, startMinute: minute, endHour: endH, endMinute: endM, excludingSegmentId: segment.id) else { return }
        } else {
            guard !entry.hasOverlap(startHour: hour, startMinute: minute, endHour: 23, endMinute: 59, excludingSegmentId: segment.id) else { return }
        }

        entries[entryIndex].segments[segIndex] = WorkSegment(
            id: segment.id,
            startHour: hour,
            startMinute: minute,
            endHour: segment.endHour,
            endMinute: segment.endMinute,
            project: segment.project
        )
        StorageService.shared.saveAll(entries)
        revision += 1

        if entries[entryIndex].id == currentTimeEntry?.id {
            currentTimeEntry = entries[entryIndex]
            tick()
        }
    }

    func updateSegmentEndForEntry(entryId: UUID, segmentId: UUID, hour: Int, minute: Int) {
        var entries = StorageService.shared.loadAll()
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }
        guard let segIndex = entries[entryIndex].segments.firstIndex(where: { $0.id == segmentId }) else { return }

        let segment = entries[entryIndex].segments[segIndex]
        guard segment.isCompleted else { return }
        guard (hour * 60 + minute) > (segment.startHour * 60 + segment.startMinute) else { return }
        guard !entries[entryIndex].hasOverlap(startHour: segment.startHour, startMinute: segment.startMinute, endHour: hour, endMinute: minute, excludingSegmentId: segment.id) else { return }

        entries[entryIndex].segments[segIndex] = WorkSegment(
            id: segment.id,
            startHour: segment.startHour,
            startMinute: segment.startMinute,
            endHour: hour,
            endMinute: minute,
            project: segment.project
        )
        StorageService.shared.saveAll(entries)
        revision += 1

        if entries[entryIndex].id == currentTimeEntry?.id {
            currentTimeEntry = entries[entryIndex]
            tick()
        }
    }

    func deleteSegmentFromEntry(entryId: UUID, segmentId: UUID) {
        var entries = StorageService.shared.loadAll()
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }

        entries[entryIndex].segments.removeAll { $0.id == segmentId }

        // Fix delete bug: if no segments left, remove the entry entirely
        if entries[entryIndex].segments.isEmpty {
            let entryId = entries[entryIndex].id
            entries.remove(at: entryIndex)
            StorageService.shared.saveAll(entries)
            revision += 1
            if currentTimeEntry?.id == entryId {
                currentTimeEntry = nil
                isRunning = false
                tick()
            }
        } else {
            StorageService.shared.saveAll(entries)
            revision += 1
            if entries[entryIndex].id == currentTimeEntry?.id {
                currentTimeEntry = entries[entryIndex]
                tick()
            }
        }
    }

    func updateProjectForEntry(entryId: UUID, project: String) {
        var entries = StorageService.shared.loadAll()
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[index].project = project
        StorageService.shared.saveAll(entries)
        revision += 1
        if entries[index].id == currentTimeEntry?.id {
            currentTimeEntry = entries[index]
        }
    }

    func addSegmentToEntry(entryId: UUID, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, project: String = "") {
        var entries = StorageService.shared.loadAll()
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        guard (endHour * 60 + endMinute) > (startHour * 60 + startMinute) else { return }
        guard !entries[index].hasOverlap(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute) else { return }
        entries[index].segments.append(WorkSegment(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            project: project
        ))
        StorageService.shared.saveAll(entries)
        revision += 1
        if entries[index].id == currentTimeEntry?.id {
            currentTimeEntry = entries[index]
            tick()
        }
    }

    func updateSegmentProjectForEntry(entryId: UUID, segmentId: UUID, project: String) {
        var entries = StorageService.shared.loadAll()
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }
        guard let segIndex = entries[entryIndex].segments.firstIndex(where: { $0.id == segmentId }) else { return }
        entries[entryIndex].segments[segIndex].project = project
        StorageService.shared.saveAll(entries)
        revision += 1
        if entries[entryIndex].id == currentTimeEntry?.id {
            currentTimeEntry = entries[entryIndex]
        }
    }

    func addEntryForDate(_ date: Date, project: String = "") {
        let scheduled = scheduleManager?.scheduledSeconds(for: date) ?? 0
        let entry = TimeEntry(
            date: date,
            startTime: Calendar.current.startOfDay(for: date),
            segments: [],
            scheduledSeconds: scheduled,
            project: project
        )
        StorageService.shared.save(entry)
        revision += 1
    }

    private func removeOverlappingWithLastSegment(at index: Array<WorkSegment>.Index?) {
        guard let idx = index, var entry = currentTimeEntry, idx < entry.segments.count else { return }
        let seg = entry.segments[idx]
        guard let eh = seg.endHour, let em = seg.endMinute else { return }
        entry.removeSegmentsOverlapping(startHour: seg.startHour, startMinute: seg.startMinute, endHour: eh, endMinute: em, excluding: seg.id)
        currentTimeEntry = entry
    }

    // MARK: - Display Timer

    private func startDisplayTimer() {
        stopDisplayTimer()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        tick()
    }

    private func stopDisplayTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        if let entry = currentTimeEntry {
            let today = Calendar.current.startOfDay(for: Date())
            let entryDay = Calendar.current.startOfDay(for: entry.date)

            if entryDay != today && isRunning {
                // Only create new entry if timer is running and day has changed
                var stoppedEntry = entry
                stoppedEntry.stopSegment()
                StorageService.shared.save(stoppedEntry)

                let now = Date()
                let scheduled = scheduleManager?.scheduledSeconds(for: now) ?? 0
                var newEntry = TimeEntry(
                    date: now,
                    startTime: now,
                    segments: [],
                    scheduledSeconds: scheduled,
                    project: entry.project
                )
                newEntry.startSegment()
                currentTimeEntry = newEntry
                isRunning = true
                alertFiredToday = false
                save()
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

        checkAlert()
    }

    // MARK: - Alert Check

    private func checkAlert() {
        guard let entry = currentTimeEntry else { return }
        guard scheduleManager?.config.alertSoundEnabled == true else { return }

        let threshold = TimeInterval(scheduleManager?.config.alertMinutesBeforeEnd ?? 10) * 60
        let remaining = entry.scheduledSeconds - elapsedTime

        if remaining <= threshold && remaining > threshold - 2 && !alertFiredToday {
            alertFiredToday = true
            if let sound = NSSound(named: .init("Glass")) {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }

    // MARK: - Load Today

    func loadToday() {
        alertFiredToday = false
        let today = Calendar.current.startOfDay(for: Date())

        if let existing = StorageService.shared.getEntry(for: Date()) {
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
                    StorageService.shared.save(stoppedEntry)
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

    // MARK: - Week Summary

    func currentWeekEntries() -> [TimeEntry] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        return StorageService.shared.loadAll().filter { entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            return entryDay >= weekInterval.start && entryDay < weekInterval.end
        }
    }

    func weekTotalWorked() -> TimeInterval {
        currentWeekEntries().reduce(0) { $0 + $1.totalWorkedSeconds }
    }

    func weekTotalScheduled() -> TimeInterval {
        currentWeekEntries().reduce(0) { $0 + $1.scheduledSeconds }
    }

    // MARK: - Persistence

    private func save() {
        guard let entry = currentTimeEntry else { return }
        StorageService.shared.save(entry)
        revision += 1
    }
}
