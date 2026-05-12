import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var timerController: TimerController
    @State private var showingDeleteConfirmation = false

    let weekdays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 4)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.sectionSpacing + 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        DS.sectionHeader("Weekly schedule")
                            .padding(.horizontal, DS.hPadding)

                        VStack(spacing: 0) {
                            ForEach(weekdays, id: \.self) { weekday in
                                HStack {
                                    Text(ScheduleConfig.weekdayName(for: weekday))
                                        .font(.system(size: 12))
                                        .frame(width: 100, alignment: .leading)

                                    Spacer()

                                    let (hours, minutes) = scheduleManager.getHoursMinutes(for: weekday)
                                    DatePicker("", selection: Binding(
                                        get: {
                                            Calendar.current.date(bySettingHour: hours, minute: minutes, second: 0, of: Date()) ?? Date()
                                        },
                                        set: {
                                            let cal = Calendar.current
                                            let c = cal.dateComponents([.hour, .minute], from: $0)
                                            scheduleManager.setHoursMinutes(hours: c.hour ?? 0, minutes: c.minute ?? 0, for: weekday)
                                        }
                                    ), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .frame(width: 80)
                                }
                                .padding(.horizontal, DS.hPadding)
                                .padding(.vertical, DS.rowVPadding)

                                if weekday != 1 {
                                    Divider().padding(.leading, DS.hPadding)
                                }
                            }
                        }
                        .background(DS.cardBackground)
                        .cornerRadius(DS.cornerRadius)
                    }
                    .padding(.horizontal, DS.hPadding)

                    VStack(alignment: .leading, spacing: 4) {
                        DS.sectionHeader("Alerts")
                            .padding(.horizontal, DS.hPadding)

                        VStack(spacing: 0) {
                            Toggle(isOn: Binding(
                                get: { scheduleManager.config.alertSoundEnabled },
                                set: {
                                    scheduleManager.objectWillChange.send()
                                    scheduleManager.config.alertSoundEnabled = $0
                                    scheduleManager.save()
                                }
                            )) {
                                Text("Alert sound", bundle: .module)
                            }
                            .font(.system(size: 12))
                            .padding(.horizontal, DS.hPadding)
                            .padding(.vertical, 10)

                            Divider().padding(.leading, DS.hPadding)

                            HStack {
                                Text("Minutes before ending", bundle: .module)
                                    .font(.system(size: 12))
                                Spacer()
                                Stepper(value: Binding(
                                    get: { scheduleManager.config.alertMinutesBeforeEnd },
                                    set: {
                                        scheduleManager.objectWillChange.send()
                                        scheduleManager.config.alertMinutesBeforeEnd = $0
                                        scheduleManager.save()
                                    }
                                ), in: 1...60, step: 5) {
                                    Text("\(scheduleManager.config.alertMinutesBeforeEnd) min")
                                        .font(DS.monoFont)
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                            .padding(.horizontal, DS.hPadding)
                            .padding(.vertical, 10)
                        }
                        .background(DS.cardBackground)
                        .cornerRadius(DS.cornerRadius)
                    }
                    .padding(.horizontal, DS.hPadding)

                    VStack(alignment: .leading, spacing: 4) {
                        DS.sectionHeader("Data")
                            .padding(.horizontal, DS.hPadding)

                        VStack(spacing: 0) {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label {
                                    Text("Delete all data", bundle: .module)
                                } icon: {
                                    Image(systemName: "trash.fill")
                                }
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .padding(10)
                        }
                        .background(DS.cardBackground)
                        .cornerRadius(DS.cornerRadius)
                    }
                    .padding(.horizontal, DS.hPadding)
                }
                .padding(.bottom, 16)
            }
        }
        .alert(Text("Delete all data?", bundle: .module), isPresented: $showingDeleteConfirmation) {
            Button(role: .cancel) {} label: { Text("Cancel", bundle: .module) }
            Button(role: .destructive) {
                timerController.repository?.deleteAll()
                timerController.currentTimeEntry = nil
                timerController.isRunning = false
                timerController.elapsedTime = 0
                timerController.remainingTime = scheduleManager.scheduledSeconds(for: Date())
                timerController.progress = 0
            } label: { Text("Delete", bundle: .module) }
        } message: {
            Text("This will permanently delete all work records. This action cannot be undone.", bundle: .module)
        }
    }
}
