import SwiftUI

struct TimerView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var showingPeriodEditor = false

    var body: some View {
        VStack(spacing: DS.sectionSpacing) {
            Spacer().frame(height: 4)

            Text(formatTime(timerManager.elapsedTime))
                .font(.system(size: 40, weight: .light, design: .monospaced))
                .foregroundStyle(timerManager.isRunning ? .primary : .secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(
                        timerManager.progress >= 1.0 ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.progress)

                VStack(spacing: 2) {
                    Text("\(Int(timerManager.progress * 100))%")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    if timerManager.remainingTime > 0 {
                        Text(formatTime(timerManager.remainingTime))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else if timerManager.remainingTime < 0 {
                        Text("+\(formatTime(abs(timerManager.remainingTime)))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(width: 96, height: 96)

            if let entry = timerManager.currentTimeEntry,
               let endTime = scheduleManager.expectedEndTime(startTime: entry.startTime) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Fin previsto: \(endTime, style: .time)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            // Action button
            HStack {
                actionButton
            }
            .padding(.horizontal, DS.hPadding)

            Divider()
                .padding(.horizontal, DS.hPadding)

            // Today's periods
            todayPeriodsSection

            Divider()
                .padding(.horizontal, DS.hPadding)

            // Week summary
            weekSummarySection
                .padding(.horizontal, DS.hPadding)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingPeriodEditor) {
            PeriodEditorView(timerManager: timerManager)
                .frame(minWidth: 520, minHeight: 440)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if timerManager.currentTimeEntry == nil {
            Button(action: { timerManager.startSession() }) {
                Label("Iniciar", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if timerManager.isRunning {
            Button(action: { timerManager.pauseSession() }) {
                Label("Pausar", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
        } else {
            Button(action: { timerManager.resumeSession() }) {
                Label("Reanudar", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var todayPeriodsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                DS.sectionHeader("Periodos de hoy")
                Spacer()
                Button(action: { showingPeriodEditor = true }) {
                    Image(systemName: "rectangle.expand.vertical")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Editor de periodos")
            }

            let todayEntry = timerManager.currentTimeEntry ?? StorageService.shared.getEntry(for: Date())

            if let entry = todayEntry, !entry.segments.isEmpty {
                PeriodTable(
                    segments: entry.segments,
                    entryId: entry.id,
                    timerManager: timerManager
                )
            } else {
                HStack {
                    DS.sectionHeader("Sin periodos")
                        .foregroundStyle(DS.tertiaryColor)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, DS.hPadding)
    }

    private var weekSummarySection: some View {
        let weekWorked = timerManager.weekTotalWorked()
        let weekScheduled = timerManager.weekTotalScheduled()

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                DS.sectionHeader("Esta semana")
                Text(formatTimeShort(weekWorked))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            }
            Spacer()
            if weekScheduled > 0 {
                let progress = min(weekWorked / weekScheduled, 1.0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("de \(formatTimeShort(weekScheduled))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    ProgressView(value: progress)
                        .frame(width: 80)
                }
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatTimeShort(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

// MARK: - Period Table (shared between TimerView and PeriodEditorView)

struct PeriodTable: View {
    let segments: [WorkSegment]
    let entryId: UUID
    @ObservedObject var timerManager: TimerManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                PeriodRowCompact(
                    segment: segment,
                    entryId: entryId,
                    timerManager: timerManager
                )
                .background(index % 2 == 1 ? Color.primary.opacity(0.03) : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct PeriodRowCompact: View {
    let segment: WorkSegment
    let entryId: UUID
    @ObservedObject var timerManager: TimerManager

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(max(0, duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 6) {
                Circle()
                    .fill(segment.endHour == nil ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)

                Text(timeString(hour: segment.startHour, minute: segment.startMinute))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(width: 56)

                Text("–")
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                if let endH = segment.endHour, let endM = segment.endMinute {
                    Text(timeString(hour: endH, minute: endM))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(width: 56)
                } else {
                    Text("ahora")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 56)
                }

                Text(formatDuration(segment.duration))
                    .font(DS.monoFont)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)

                Spacer().frame(width: 4)

                Text(segment.project)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.tertiaryColor)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    timerManager.deleteSegmentFromEntry(entryId: entryId, segmentId: segment.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

extension PeriodRowCompact {
    private func timeString(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
