import Foundation

let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withFullDate]
let date = Calendar.current.startOfDay(for: Date())
print("Date: \(date)")
print("Formatted: \(formatter.string(from: date))")
print("Parsed: \(formatter.date(from: formatter.string(from: date)) ?? Date())")
