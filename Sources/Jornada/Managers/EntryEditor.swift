import Foundation
import AppKit

@MainActor
final class EntryEditor: ObservableObject {
    weak var timerController: TimerController?
    var repository: EntryRepository?
    var scheduleManager: ScheduleManager?

    func updateSegmentStartForEntry(entryId: UUID, segmentId: UUID, hour: Int, minute: Int) {
        var entries = repository?.loadAll() ?? []
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }
        do {
            try entries[entryIndex].validateAndUpdateSegmentStart(segmentId: segmentId, hour: hour, minute: minute)
            repository?.save(entries[entryIndex])
            timerController?.revision += 1
            if entries[entryIndex].id == timerController?.currentTimeEntry?.id {
                timerController?.currentTimeEntry = entries[entryIndex]
                timerController?.objectWillChange.send()
            }
        } catch {
            NSSound.beep()
        }
    }

    func updateSegmentEndForEntry(entryId: UUID, segmentId: UUID, hour: Int, minute: Int) {
        var entries = repository?.loadAll() ?? []
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }
        do {
            try entries[entryIndex].validateAndUpdateSegmentEnd(segmentId: segmentId, hour: hour, minute: minute)
            repository?.save(entries[entryIndex])
            timerController?.revision += 1
            if entries[entryIndex].id == timerController?.currentTimeEntry?.id {
                timerController?.currentTimeEntry = entries[entryIndex]
                timerController?.objectWillChange.send()
            }
        } catch {
            NSSound.beep()
        }
    }

    func deleteSegmentFromEntry(entryId: UUID, segmentId: UUID) {
        var entries = repository?.loadAll() ?? []
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }
        let entry = entries[entryIndex]
        let removedId = entry.id

        if entry.segments.count == 1 && entry.segments[0].id == segmentId {
            repository?.delete(entry)
            timerController?.revision += 1
            if timerController?.currentTimeEntry?.id == removedId {
                timerController?.currentTimeEntry = nil
                timerController?.isRunning = false
            }
        } else {
            var modified = entry
            modified.segments.removeAll { $0.id == segmentId }
            repository?.save(modified)
            timerController?.revision += 1
            if modified.id == timerController?.currentTimeEntry?.id {
                timerController?.currentTimeEntry = modified
                timerController?.objectWillChange.send()
            }
        }
    }

    func updateProjectForEntry(entryId: UUID, project: String) {
        var entries = repository?.loadAll() ?? []
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        var entry = entries[index]
        entry.project = project
        repository?.save(entry)
        timerController?.revision += 1
        if entry.id == timerController?.currentTimeEntry?.id {
            timerController?.currentTimeEntry = entry
        }
    }

    func addSegmentToEntry(entryId: UUID, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, project: String = "") {
        var entries = repository?.loadAll() ?? []
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        guard (endHour * 60 + endMinute) > (startHour * 60 + startMinute) else {
            NSSound.beep(); return
        }
        guard !entries[index].hasOverlap(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute) else {
            NSSound.beep(); return
        }
        var entry = entries[index]
        entry.segments.append(WorkSegment(
            date: entry.date,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            project: project
        ))
        repository?.save(entry)
        timerController?.revision += 1
        if entry.id == timerController?.currentTimeEntry?.id {
            timerController?.currentTimeEntry = entry
            timerController?.objectWillChange.send()
        }
    }

    func updateSegmentProjectForEntry(entryId: UUID, segmentId: UUID, project: String) {
        var entries = repository?.loadAll() ?? []
        guard let entryIndex = entries.firstIndex(where: { $0.id == entryId }) else { return }
        guard let segIndex = entries[entryIndex].segments.firstIndex(where: { $0.id == segmentId }) else { return }
        var entry = entries[entryIndex]
        entry.segments[segIndex].project = project
        repository?.save(entry)
        timerController?.revision += 1
        if entry.id == timerController?.currentTimeEntry?.id {
            timerController?.currentTimeEntry = entry
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
        repository?.save(entry)
        timerController?.revision += 1
    }
}
