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
                .environmentObject(appDelegate.timerManager)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var contextMenu: NSMenu!

    let timerManager = TimerManager()
    let scheduleManager = ScheduleManager()

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        timerManager.scheduleManager = scheduleManager

        timerManager.loadToday()

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
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover()
                .environmentObject(timerManager)
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

        if timerManager.isRunning {
            let stopItem = NSMenuItem(
                title: "Detener",
                action: #selector(stopTimer),
                keyEquivalent: "d"
            )
            stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Detener")
            contextMenu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(
                title: "Iniciar",
                action: #selector(startOrResumeTimer),
                keyEquivalent: "s"
            )
            startItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Iniciar")
            contextMenu.addItem(startItem)
        }

        contextMenu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(
            title: "Mostrar ventana",
            action: #selector(showPopover),
            keyEquivalent: "w"
        )
        showItem.image = NSImage(systemSymbolName: "window", accessibilityDescription: "Mostrar ventana")
        contextMenu.addItem(showItem)

        contextMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Cerrar Jornada",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cerrar aplicación")
        contextMenu.addItem(quitItem)
    }

    @objc func startTimer() {
        timerManager.startSession()
    }

    @objc func pauseTimer() {
        timerManager.pauseSession()
    }

    @objc func resumeTimer() {
        timerManager.resumeSession()
    }

    @objc func startOrResumeTimer() {
        if timerManager.currentTimeEntry != nil {
            timerManager.resumeSession()
        } else {
            timerManager.startSession()
        }
    }

    @objc func stopTimer() {
        timerManager.stopSession()
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
        if timerManager.isRunning {
            total = timerManager.elapsedTime
        } else if let entry = timerManager.currentTimeEntry {
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
