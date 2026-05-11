import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var timerManager: TimerManager
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
                        .environmentObject(timerManager)
                        .environmentObject(scheduleManager)
                case 1:
                    HistoryView()
                        .environmentObject(timerManager)
                        .environmentObject(scheduleManager)
                case 2:
                    SettingsView()
                        .environmentObject(scheduleManager)
                        .environmentObject(timerManager)
                default:
                    EmptyView()
                }
            }
        }
        .frame(width: 360, height: 500)
    }
}
