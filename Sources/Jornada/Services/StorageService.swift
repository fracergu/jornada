import Foundation

class StorageService {
    static let shared = StorageService()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Jornada")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var entriesURL: URL {
        storageDirectory.appendingPathComponent("entries.json")
    }

    private var csvURL: URL {
        storageDirectory.appendingPathComponent("entries.csv")
    }

    private var entries: [TimeEntry] = []

    init() {
        entries = loadFromDisk()
        migrateCSVIfNeeded()
    }

    // MARK: - Public API

    func loadAll() -> [TimeEntry] {
        return entries
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
        entries = newEntries
        saveToDisk()
    }

    func delete(_ entry: TimeEntry) {
        entries.removeAll { $0.id == entry.id }
        saveToDisk()
    }

    func deleteAllData() {
        entries = []
        saveToDisk()
        try? FileManager.default.removeItem(at: entriesURL)
    }

    func getEntry(for date: Date) -> TimeEntry? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }
    }

    func saveAll(_ entriesToExport: [TimeEntry], to url: URL) {
        let csv = generateCSV(entriesToExport)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    func exportCSV(to url: URL) -> Bool {
        let csv = generateCSV(entries)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("StorageService: Export failed - \(error)")
            return false
        }
    }

    func importCSV(from url: URL) -> [TimeEntry]? {
        guard let data = FileManager.default.contents(atPath: url.path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        let imported = parseCSV(content)
        return imported.isEmpty && !content.contains("id") ? nil : imported
    }

    // MARK: - Disk I/O

    private func loadFromDisk() -> [TimeEntry] {
        guard FileManager.default.fileExists(atPath: entriesURL.path),
              let data = FileManager.default.contents(atPath: entriesURL.path) else {
            return []
        }
        return (try? decoder.decode([TimeEntry].self, from: data)) ?? []
    }

    private func saveToDisk() {
        guard let data = try? encoder.encode(entries) else {
            print("StorageService: Failed to encode entries")
            return
        }
        do {
            try data.write(to: entriesURL, options: .atomic)
        } catch {
            print("StorageService: Failed to write - \(error)")
        }
    }

    // MARK: - CSV Migration

    private func migrateCSVIfNeeded() {
        guard FileManager.default.fileExists(atPath: csvURL.path) else { return }
        guard entries.isEmpty else {
            try? FileManager.default.removeItem(at: csvURL)
            return
        }

        guard let csvData = FileManager.default.contents(atPath: csvURL.path),
              let csvContent = String(data: csvData, encoding: .utf8) else { return }

        let imported = parseCSV(csvContent)
        if !imported.isEmpty {
            entries = imported
            saveToDisk()
        }

        let backupURL = storageDirectory.appendingPathComponent("entries.csv.bak")
        try? FileManager.default.moveItem(at: csvURL, to: backupURL)
    }

    // MARK: - CSV Helpers

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private let dateTimeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func generateCSV(_ entries: [TimeEntry]) -> String {
        var lines: [String] = ["id,date,startTime,scheduledSeconds,segments_json,notes,project"]

        for entry in entries {
            let segmentsData = (try? encoder.encode(entry.segments)) ?? Data()
            let segmentsJSON = String(data: segmentsData, encoding: .utf8) ?? "[]"

            let fields = [
                entry.id.uuidString,
                dateFormatter.string(from: entry.date),
                dateTimeFormatter.string(from: entry.startTime),
                String(entry.scheduledSeconds),
                segmentsJSON,
                entry.notes,
                entry.project
            ]

            lines.append(fields.map { escapeCSVField($0) }.joined(separator: ","))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func parseCSV(_ content: String) -> [TimeEntry] {
        let lines = splitLines(content)
        guard lines.count > 1 else { return [] }

        var result: [TimeEntry] = []

        for i in 1..<lines.count {
            let line = lines[i]
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let fields = parseCSVLine(line)
            guard fields.count >= 6,
                  let id = UUID(uuidString: fields[0]),
                  let date = dateFormatter.date(from: fields[1]),
                  let startTime = dateTimeFormatter.date(from: fields[2]),
                  let scheduledSeconds = Double(fields[3]) else {
                continue
            }

            let segmentsJSON = fields[4]
            let notes = fields.count > 5 ? fields[5] : ""
            let project = fields.count > 6 ? fields[6] : ""

            let segments: [WorkSegment]
            if let data = segmentsJSON.data(using: .utf8) {
                segments = (try? decoder.decode([WorkSegment].self, from: data)) ?? []
            } else {
                segments = []
            }

            let entry = TimeEntry(
                id: id,
                date: date,
                startTime: startTime,
                segments: segments,
                scheduledSeconds: scheduledSeconds,
                notes: notes,
                project: project
            )
            result.append(entry)
        }

        return result
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if inQuotes {
                if char == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }

            i = line.index(after: i)
        }

        fields.append(current)
        return fields
    }

    private func splitLines(_ content: String) -> [String] {
        var lines: [String] = []
        var current = ""
        var inQuotes = false

        for char in content {
            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
            } else if (char == "\n" || char == "\r") && !inQuotes {
                if !current.isEmpty {
                    lines.append(current)
                }
                current = ""
                if char == "\r" { continue }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        return lines
    }
}
