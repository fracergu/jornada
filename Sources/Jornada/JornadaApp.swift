import SwiftUI
import AppKit
import Combine

@main
struct JornadaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.scheduleManager)
                .environmentObject(appDelegate.timerController)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var contextMenu: NSMenu!

    let timerController = TimerController()
    let entryEditor = EntryEditor()
    let scheduleManager = ScheduleManager()
    let alertService = AlertService()
    let repository: EntryRepository

    private var cancellables = Set<AnyCancellable>()

    override init() {
        repository = JSONFileRepository.shared
        super.init()

        timerController.repository = repository
        timerController.scheduleManager = scheduleManager
        timerController.alertService = alertService

        entryEditor.repository = repository
        entryEditor.timerController = timerController
        entryEditor.scheduleManager = scheduleManager
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        timerController.loadToday()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Jornada")
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        contextMenu = NSMenu()
        contextMenu.delegate = self

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover()
                .environmentObject(timerController)
                .environmentObject(entryEditor)
                .environmentObject(scheduleManager)
        )

        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStatusTitle()
            }
            .store(in: &cancellables)
    }

    @objc func togglePopover(_ sender: NSButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown || event?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }

        updateContextMenu()

        contextMenu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.frame.height),
            in: button
        )
    }

    private func updateContextMenu() {
        contextMenu.removeAllItems()

        if timerController.isRunning {
            let stopItem = NSMenuItem(
                title: String(localized: "Stop", bundle: .module),
                action: #selector(stopTimer),
                keyEquivalent: "d"
            )
            stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: String(localized: "Stop", bundle: .module))
            contextMenu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(
                title: String(localized: "Start", bundle: .module),
                action: #selector(startTimer),
                keyEquivalent: "s"
            )
            startItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: String(localized: "Start", bundle: .module))
            contextMenu.addItem(startItem)
        }

        contextMenu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(
            title: String(localized: "Show window", bundle: .module),
            action: #selector(showPopover),
            keyEquivalent: "w"
        )
        showItem.image = NSImage(systemSymbolName: "window", accessibilityDescription: String(localized: "Show window", bundle: .module))
        contextMenu.addItem(showItem)

        contextMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: String(localized: "Quit Jornada", bundle: .module),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: String(localized: "Quit Jornada", bundle: .module))
        contextMenu.addItem(quitItem)
    }

    @objc func startTimer() {
        timerController.startSession()
    }

    @objc func stopTimer() {
        timerController.stopSession()
    }

    @objc func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }

        let total: TimeInterval
        if timerController.isRunning {
            total = timerController.elapsedTime
        } else if let entry = timerController.currentTimeEntry {
            total = entry.totalWorkedSeconds
        } else {
            button.title = ""
            return
        }

        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        button.title = String(format: " %dh %02dm", hours, minutes)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
    }
}
