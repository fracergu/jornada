import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var exportStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var exportEndDate = Date()
    @State private var showingExportPanel = false

    struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let workedHours: Double
        let scheduledHours: Double
        let dayName: String
    }

    private var weekData: [DayData] {
        _ = timerManager.revision
        let calendar = Calendar.current
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }

        let entries = timerManager.currentWeekEntries()
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEE"

        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let entry = entries.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
            let worked = entry?.totalWorkedSeconds ?? 0
            let scheduled = scheduleManager.scheduledSeconds(for: date)
            return DayData(date: date, workedHours: worked / 3600, scheduledHours: scheduled / 3600, dayName: dayFormatter.string(from: date).capitalized)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.sectionSpacing) {
            Spacer().frame(height: 4)

            DS.sectionHeader("Resumen semanal")
                .padding(.horizontal, DS.hPadding)

            Chart(weekData) { day in
                BarMark(x: .value("Día", day.dayName), y: .value("Horas", day.workedHours))
                    .foregroundStyle(day.workedHours >= day.scheduledHours ? Color.green : Color.accentColor)
                    .cornerRadius(4)
                if day.scheduledHours > 0 {
                    RuleMark(y: .value("Horario", day.scheduledHours))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(.orange)
                        .annotation(position: .top, alignment: .trailing) {
                            Text(String(format: "%.0fh", day.scheduledHours))
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                }
            }
            .chartYScale(domain: 0...max(10, weekData.map(\.workedHours).max() ?? 10))
            .frame(height: 190)
            .padding(.horizontal, DS.hPadding)

            // Stats card
            let totalWorked = weekData.reduce(0) { $0 + $1.workedHours }
            let totalScheduled = weekData.reduce(0) { $0 + $1.scheduledHours }
            let difference = totalWorked - totalScheduled

            HStack(spacing: 0) {
                statItem(label: "Trabajadas", value: String(format: "%.1fh", totalWorked), color: .primary)
                Divider().frame(height: 32)
                statItem(label: "Programadas", value: String(format: "%.1fh", totalScheduled), color: .primary)
                Divider().frame(height: 32)
                statItem(label: "Diferencia", value: String(format: "%+.1fh", difference), color: difference >= 0 ? .green : .red)
            }
            .padding(.vertical, 10)
            .background(DS.cardBackground)
            .cornerRadius(DS.cornerRadius)
            .padding(.horizontal, DS.hPadding)

            // Import/Export
            HStack(spacing: 12) {
                Button(action: { showingExportPanel = true }) {
                    Label("Exportar CSV", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: importCSV) {
                    Label("Importar CSV", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, DS.hPadding)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingExportPanel) {
            VStack(spacing: 16) {
                Text("Exportar CSV").font(.headline)
                DatePicker("Desde", selection: $exportStartDate, displayedComponents: .date)
                DatePicker("Hasta", selection: $exportEndDate, displayedComponents: .date)
                HStack {
                    Button("Cancelar") { showingExportPanel = false }.keyboardShortcut(.cancelAction)
                    Button("Exportar") { exportCSV(); showingExportPanel = false }.keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 300)
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "jornada_export.csv"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let calendar = Calendar.current
                let startDay = calendar.startOfDay(for: exportStartDate)
                let endDay = calendar.startOfDay(for: exportEndDate)
                let filtered = StorageService.shared.loadAll().filter { entry in
                    let entryDay = calendar.startOfDay(for: entry.date)
                    return entryDay >= startDay && entryDay <= endDay
                }
                StorageService.shared.saveAll(filtered, to: url)
            }
        }
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let imported = StorageService.shared.importCSV(from: url) {
                    var existing = StorageService.shared.loadAll()
                    for entry in imported {
                        if let idx = existing.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }) {
                            existing[idx] = entry
                        } else {
                            existing.append(entry)
                        }
                    }
                    StorageService.shared.saveAll(existing)
                    timerManager.loadToday()
                }
            }
        }
    }
}
