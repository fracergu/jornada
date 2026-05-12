import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var timerController: TimerController
    @EnvironmentObject var entryEditor: EntryEditor
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Image(systemName: "timer").tag(0)
                Image(systemName: "chart.bar").tag(1)
                Image(systemName: "gearshape").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.hPadding)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                switch selectedTab {
                case 0:
                    TimerView()
                        .environmentObject(timerController)
                        .environmentObject(entryEditor)
                        .environmentObject(scheduleManager)
                case 1:
                    HistoryView()
                        .environmentObject(timerController)
                        .environmentObject(scheduleManager)
                case 2:
                    SettingsView()
                        .environmentObject(scheduleManager)
                        .environmentObject(timerController)
                default:
                    EmptyView()
                }
            }
        }
        .frame(width: 360)
        .frame(minHeight: 400, maxHeight: 600)
    }
}
