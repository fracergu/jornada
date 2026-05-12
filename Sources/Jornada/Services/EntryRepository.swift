import Foundation

@MainActor
protocol EntryRepository: AnyObject {
    func loadAll() -> [TimeEntry]
    func getEntry(for date: Date) -> TimeEntry?
    func save(_ entry: TimeEntry)
    func saveAll(_ entries: [TimeEntry])
    func delete(_ entry: TimeEntry)
    func deleteAll()
}

@MainActor
final class JSONFileRepository: EntryRepository {
    static let shared: JSONFileRepository = {
        let repo = JSONFileRepository()
        repo.entries = repo.loadFromDisk()
        repo.migrateFromLegacyIfNeeded()
        return repo
    }()

    private var entries: [TimeEntry] = []

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        #if DEBUG
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        #else
        e.outputFormatting = [.sortedKeys]
        #endif
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Jornada")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    private var entriesURL: URL {
        storageDirectory.appendingPathComponent("entries.json")
    }

    private var backupURL: URL {
        storageDirectory.appendingPathComponent("entries.json.bak")
    }

    func loadAll() -> [TimeEntry] {
        return entries
    }

    func getEntry(for date: Date) -> TimeEntry? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }
    }

    func save(_ entry: TimeEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        saveToDisk()
    }

    func saveAll(_ newEntries: [TimeEntry]) {
        for newEntry in newEntries {
            if let index = entries.firstIndex(where: { $0.id == newEntry.id }) {
                entries[index] = newEntry
            } else {
                entries.append(newEntry)
            }
        }
        saveToDisk()
    }

    func delete(_ entry: TimeEntry) {
        entries.removeAll { $0.id == entry.id }
        saveToDisk()
    }

    func deleteAll() {
        entries = []
        saveToDisk()
        try? FileManager.default.removeItem(at: entriesURL)
        try? FileManager.default.removeItem(at: backupURL)
    }

    // MARK: - Atomic Disk I/O

    private func saveToDisk() {
        guard let data = try? encoder.encode(entries) else {
            print("JSONFileRepository: Failed to encode entries")
            return
        }
        let tempURL = storageDirectory.appendingPathComponent("entries.json.tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: entriesURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try FileManager.default.moveItem(at: entriesURL, to: backupURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: entriesURL)
        } catch {
            print("JSONFileRepository: Failed to write - \(error)")
        }
    }

    private func loadFromDisk() -> [TimeEntry] {
        if let data = try? Data(contentsOf: entriesURL),
           let decoded = try? decoder.decode([TimeEntry].self, from: data) {
            return decoded
        }
        if let data = try? Data(contentsOf: backupURL),
           let decoded = try? decoder.decode([TimeEntry].self, from: data) {
            print("JSONFileRepository: Restored from backup")
            return decoded
        }
        return []
    }

    // MARK: - Legacy Migration

    private func migrateFromLegacyIfNeeded() {
        let csvURL = storageDirectory.appendingPathComponent("entries.csv")
        guard FileManager.default.fileExists(atPath: csvURL.path) else { return }
        guard entries.isEmpty else {
            try? FileManager.default.removeItem(at: csvURL)
            return
        }

        if let legacyEntries = StorageService.shared.importCSV(from: csvURL) {
            entries = legacyEntries
            saveToDisk()
        }

        let bakURL = storageDirectory.appendingPathComponent("entries.csv.bak")
        try? FileManager.default.moveItem(at: csvURL, to: bakURL)
    }
}
