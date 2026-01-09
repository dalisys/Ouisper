import AppKit
import SwiftUI
import Combine

class MenuBarManager: NSObject, NSMenuItemValidation {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupMenuBar()
        setupObservers()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
            button.action = #selector(menuBarClicked)
            button.target = self
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let statusItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        
        self.statusItem.menu = menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(openSettings), #selector(quitApp):
            return true
        default:
            return menuItem.isEnabled
        }
    }
    
    private func setupObservers() {
        DictationState.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateIcon(for: status)
                self?.updateStatusText(for: status)
            }
            .store(in: &cancellables)
    }
    
    private func updateIcon(for status: DictationStatus) {
        guard let button = statusItem.button else { return }
        
        let symbolName: String
        switch status {
        case .idle, .success:
            symbolName = "MenuBarIcon"
        case .recording:
            symbolName = "record.circle.fill"
        case .processing:
            symbolName = "hourglass"
        case .refining:
            symbolName = "sparkles"
        case .error:
            symbolName = "exclamationmark.circle.fill"
        }
        
        if symbolName == "MenuBarIcon" {
            button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        } else {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        }
    }
    
    private func updateStatusText(for status: DictationStatus) {
        guard let menu = statusItem.menu, let item = menu.item(at: 0) else { return }
        
        switch status {
        case .idle:
            item.title = "Ready"
        case .recording:
            item.title = "Recording..."
        case .processing:
            item.title = "Processing..."
        case .refining:
            item.title = "Refining..."
        case .success:
            item.title = "Success"
        case .error(let msg):
            item.title = "Error: \(msg)"
        }
    }
    
    @objc private func menuBarClicked() {
        // Handle click if needed, or let the menu show automatically
        // If we wanted a popover instead of a menu, we would toggle it here.
        // For now, using standard NSMenu assigned to statusItem.menu handles the click.
    }
    
    @objc private func openSettings() {
        NSApp.sendAction(#selector(AppDelegate.openSettingsWindow), to: nil, from: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
