# Jornada

macOS menu bar time tracker. Track your work sessions per day with time segments, projects, and weekly statistics.

## Features

- **Timer** with start/stop controls and visual progress ring
- **Independent segments** — each "Start" creates a new work block, each "Stop" closes it
- **Weekly editor** — 7-day view to add, edit, or delete time periods manually
- **Projects per period** — each segment can have a different project
- **Weekly chart** — bar chart showing worked hours vs scheduled hours
- **Configurable alerts** — sound notification when approaching the end of your workday
- **Configurable weekly schedule** — set hours per day per weekday
- **Atomic JSON persistence** — writes via temp → backup → main with automatic backup recovery
- **CSV import/export** — backup or data migration
- **Internationalization** — English and Spanish, auto-detected from system language
- **Accessibility** — VoiceOver labels on timer, progress ring, and action buttons
- **Validation** — overlap detection, start-before-end enforcement, midnight crossing support

## Requirements

- macOS 14.0+
- Swift 5.10+ (`swift build`) or Xcode 16+

## Installation

### From DMG

1. Download `Jornada.dmg` from the [latest release](https://github.com/fracergu/jornada/releases)
2. Open the DMG and drag Jornada to Applications
3. If macOS blocks the app, go to System Settings > Privacy & Security and click "Open Anyway"

### From source

```bash
git clone https://github.com/fracergu/jornada.git
cd jornada
swift build -c release
./build.sh
```

## Usage

### Timer controls

- **Left click** the menu bar icon → opens the popover
- **Right click** → context menu with Start/Stop
- **Start** — begins a new work segment
- **Stop** — ends the current segment
- Each segment is independent: start and stop as many times as needed

### Period editor

From the main popover, click the expand icon (top-right corner of "Today's periods") to open the weekly editor. Here you can:

- View all 7 days with their periods
- Edit start and end times of each period
- Add new periods with the `+` button
- Assign a project to each period
- Delete completed periods with the ✗ button
- Navigate between weeks with the arrow buttons

## Tests

```bash
swift test
```

Runs 11 unit tests covering WorkSegment, TimeEntry, ScheduleConfig, and EntryRepository using the swift-testing framework.

## License

MIT
