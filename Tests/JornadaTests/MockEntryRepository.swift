import Foundation
@testable import Jornada

@MainActor
final class MockEntryRepository: EntryRepository {
    private var entries: [TimeEntry] = []

    func loadAll() -> [TimeEntry] { entries }
    func getEntry(for date: Date) -> TimeEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    func save(_ entry: TimeEntry) { entries.append(entry) }
    func saveAll(_ newEntries: [TimeEntry]) { entries = newEntries }
    func delete(_ entry: TimeEntry) { entries.removeAll { $0.id == entry.id } }
    func deleteAll() { entries.removeAll() }
}
