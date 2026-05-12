import SwiftUI

struct PeriodEditorView: View {
    @EnvironmentObject var timerController: TimerController
    @EnvironmentObject var entryEditor: EntryEditor
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Environment(\.dismiss) private var dismiss
    @State private var weekOffset: Int = 0

    private var weekStart: Date {
        let calendar = Calendar.current
        let now = Date()
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return now }
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) ?? now
    }

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
    }

    private func weekEntries() -> [TimeEntry] {
        _ = timerController.revision
        return timerController.repository?.loadAll().filter { entry in
            let entryDay = Calendar.current.startOfDay(for: entry.date)
            return entryDay >= weekStart && entryDay < weekEnd
        }.sorted { $0.date < $1.date } ?? []
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week navigator
            HStack {
                Button(action: { weekOffset -= 1 }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(weekRangeLabel)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: { weekOffset += 1 }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless)
                .disabled(weekOffset >= 0)
            }
            .padding(.horizontal, DS.hPadding)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    let entries = weekEntries()
                    ForEach(weekDays, id: \.self) { day in
                        EditorDaySection(
                            day: day,
                            entry: entries.first { Calendar.current.isDate($0.date, inSameDayAs: day) },
                            isToday: Calendar.current.isDateInToday(day),
                            entryEditor: entryEditor,
                            timerController: timerController
                        )
                        Divider()
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button { dismiss() } label: { Text("Close", bundle: .module) }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
            .padding(.horizontal, DS.hPadding)
            .padding(.vertical, 10)
        }
    }

    private var weekRangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: weekStart)
        let end = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: weekEnd) ?? weekEnd)
        return "\(start) – \(end)"
    }
}

// MARK: - Editor Day Section

private struct EditorDaySection: View {
    let day: Date
    let entry: TimeEntry?
    let isToday: Bool
    let entryEditor: EntryEditor
    let timerController: TimerController

    @State private var showingAddPeriod = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(Self.dateFormatter.string(from: day).capitalized)
                    .font(.system(size: 12, weight: isToday ? .semibold : .medium))
                    .foregroundStyle(isToday ? .primary : .secondary)

                if isToday {
                    (Text("· ") + Text("today", bundle: .module))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let entry = entry {
                    let total = entry.totalWorkedSeconds
                    Text(formatShort(total))
                        .font(DS.monoFont)
                        .foregroundStyle(.secondary)
                }

                Button(action: {
                    if entry == nil { entryEditor.addEntryForDate(day) }
                    showingAddPeriod = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, DS.hPadding)
            .padding(.vertical, 10)

            if let entry = entry, !entry.segments.isEmpty {
                VStack(spacing: 1) {
                    ForEach(entry.segments) { segment in
                        EditorPeriodTableRow(
                            entryId: entry.id,
                            segment: segment,
                            entryEditor: entryEditor
                        )
                    }
                }
                .padding(.bottom, 4)
            } else if showingAddPeriod {
            } else {
                HStack {
                    Text("No periods", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.tertiaryColor)
                    Spacer()
                }
                .padding(.horizontal, DS.hPadding)
                .padding(.vertical, 6)
            }

            if showingAddPeriod, let entry = entry {
                EditorAddPeriodRow(entryId: entry.id, entryEditor: entryEditor, isPresented: $showingAddPeriod)
            }
        }
    }

    private func formatShort(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        return String(format: "%dh %02dm", total / 3600, (total % 3600) / 60)
    }
}

// MARK: - Editor Period Table Row

private struct EditorPeriodTableRow: View {
    let entryId: UUID
    let segment: WorkSegment
    @State private var projectText: String
    let entryEditor: EntryEditor

    init(entryId: UUID, segment: WorkSegment, entryEditor: EntryEditor) {
        self.entryId = entryId
        self.segment = segment
        self.entryEditor = entryEditor
        _projectText = State(initialValue: segment.project)
    }

    private func dateFromHourMinute(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(max(0, duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(segment.endHour == nil ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)

            DatePicker("", selection: Binding(
                get: { dateFromHourMinute(hour: segment.startHour, minute: segment.startMinute) },
                set: {
                    let cal = Calendar.current
                    entryEditor.updateSegmentStartForEntry(
                        entryId: entryId, segmentId: segment.id,
                        hour: cal.component(.hour, from: $0), minute: cal.component(.minute, from: $0)
                    )
                }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .frame(width: 64)

            Text("–").foregroundStyle(.secondary).frame(width: 10)

            if let endH = segment.endHour, let endM = segment.endMinute {
                DatePicker("", selection: Binding(
                    get: { dateFromHourMinute(hour: endH, minute: endM) },
                    set: {
                        let cal = Calendar.current
                        entryEditor.updateSegmentEndForEntry(
                            entryId: entryId, segmentId: segment.id,
                            hour: cal.component(.hour, from: $0), minute: cal.component(.minute, from: $0)
                        )
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: 64)
            } else {
                Text("now", bundle: .module).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).frame(width: 64)
            }

            Text(formatDuration(segment.duration))
                .font(DS.monoFont)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            TextField("Project", text: $projectText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .onSubmit {
                    entryEditor.updateSegmentProjectForEntry(entryId: entryId, segmentId: segment.id, project: projectText)
                }

            Spacer()

            if segment.isCompleted {
                Button(action: {
                    entryEditor.deleteSegmentFromEntry(entryId: entryId, segmentId: segment.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, DS.hPadding)
        .padding(.vertical, 5)
    }
}

// MARK: - Add Period Row

private struct EditorAddPeriodRow: View {
    let entryId: UUID
    let entryEditor: EntryEditor
    @Binding var isPresented: Bool

    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 10
    @State private var endMinute = 0
    @State private var project = ""

    private var startMins: Int { startHour * 60 + startMinute }
    private var endMins: Int { endHour * 60 + endMinute }
    private var isValidRange: Bool { endMins > startMins }

    private var hasOverlap: Bool {
        guard let entry = entryEditor.timerController?.repository?.loadAll().first(where: { $0.id == entryId }) else { return false }
        return entry.hasOverlap(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute)
    }

    private var canSave: Bool { isValidRange && !hasOverlap }

    private func dateFromHourMinute(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(Color.accentColor.opacity(0.4)).frame(width: 7, height: 7)

                DatePicker("", selection: Binding(
                    get: { dateFromHourMinute(hour: startHour, minute: startMinute) },
                    set: {
                        let cal = Calendar.current
                        startHour = cal.component(.hour, from: $0)
                        startMinute = cal.component(.minute, from: $0)
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: 64)

                Text("–").foregroundStyle(.secondary).frame(width: 10)

                DatePicker("", selection: Binding(
                    get: { dateFromHourMinute(hour: endHour, minute: endMinute) },
                    set: {
                        let cal = Calendar.current
                        endHour = cal.component(.hour, from: $0)
                        endMinute = cal.component(.minute, from: $0)
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: 64)

                TextField("Project", text: $project)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 100)

                Spacer()

                Button(action: {
                    entryEditor.addSegmentToEntry(entryId: entryId, startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute, project: project)
                    isPresented = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(canSave ? Color.green : Color.gray.opacity(0.4))
                }
                .buttonStyle(.borderless)
                .disabled(!canSave)

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.borderless)
            }

            if !isValidRange {
                HStack {
                    Spacer().frame(width: 13 + 64 + 10 + 64 + 4)
                    Text("Start must be before end", bundle: .module)
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                    Spacer()
                }
            } else if hasOverlap {
                HStack {
                    Spacer().frame(width: 13 + 64 + 10 + 64 + 4)
                    Text("Period overlaps with another", bundle: .module)
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.hPadding)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.05))
    }
}
