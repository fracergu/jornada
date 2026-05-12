import Foundation

// Legacy storage utility. Kept for CSV import/export only.
// All regular persistence is handled by JSONFileRepository.
@MainActor
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

    func saveAll(_ entriesToExport: [TimeEntry], to url: URL) {
        let csv = generateCSV(entriesToExport)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    func importCSV(from url: URL) -> [TimeEntry]? {
        guard let data = FileManager.default.contents(atPath: url.path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        let imported = parseCSV(content)
        return imported.isEmpty && !content.contains("id") ? nil : imported
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
