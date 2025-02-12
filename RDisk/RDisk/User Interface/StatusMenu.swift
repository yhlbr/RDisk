//
//  StatusMenu.swift
//  RDisk
//
//  Created by Stoyan Stoyanov on 18/12/2019.
//  Copyright © 2019 Stoyan Stoyanov. All rights reserved.
//

import Cocoa
import ServiceManagement
import RAMDiskManager

// MARK: - Singleton Instance

extension StatusMenu {
    
    /// Shared instance of the app's status bar menu.
    static let shared = StatusMenu()
    
    /// The bundle identifier of the auto launch helper program.
    static let helperBundleName = "net.stoyanstoyanov.RDisk.AutoLaunchHelper"
}

// MARK: - Class Definition

/// Class containing all logic regarding the status menu of the app. Think of it as the status bar icon.
///
/// The way to use it is by its shared instance.
final class StatusMenu: NSObject {
    
    /// Retain hook for the system's status bar item.
    private var statusBarItem: NSStatusItem
    
    /// Property used for storing the auto launch on login status.
    private var autoLaunchIsOn: Bool
    
    /// Init should not be called, use `.shared` instead.
    private override init() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.title = "R"
        statusBarItem.button?.font = NSFont.systemFont(ofSize: 18)
        
        let foundHelper = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == StatusMenu.helperBundleName }
        autoLaunchIsOn = foundHelper ? true : false
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateStatusBarMenu), name: .ramDisksWereUpdated, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .ramDisksWereUpdated, object: nil)
    }
}

// MARK: - Status Bar Menu

extension StatusMenu {
    
    /// Method used for showing generating the status bar menu and presenting it in the status bar.
    func show() {
        updateStatusBarMenu()
    }
    
    /// Creates the status bar menu,
    @objc private func updateStatusBarMenu() {
        
        let statusBarMenu = NSMenu(title: "RDisk Status Bar Menu")
        statusBarItem.menu = statusBarMenu
        
        prepareDiskSectionFor(statusBarMenu)
        statusBarMenu.addItem(NSMenuItem.separator())
        preparePreferencesSectionFor(statusBarMenu)
        statusBarMenu.addItem(NSMenuItem.separator())
        prepareQuitSectionFor(statusBarMenu)
    }
}

// MARK: - Menu Entries

extension StatusMenu {
    
    private func prepareDiskSectionFor(_ statusBarMenu: NSMenu) {
        let create = statusBarMenu.addItem(withTitle: "Create New RAM Disk...", action: #selector(createNewDisk), keyEquivalent: "")
        create.target = self
        
        let statusItem = statusBarMenu.addItem(withTitle: "Created Disks", action: nil, keyEquivalent: "")
        let subMenu = NSMenu(title: "Created Disks Submenu")
        
        if RAMDiskManager.shared.mountedRAMDisks.isEmpty {
            subMenu.addItem(withTitle: "No Disks...", action: nil, keyEquivalent: "")
        } else {
            RAMDiskManager.shared.mountedRAMDisks.enumerated().forEach { index, element in
                let item = subMenu.addItem(withTitle: "\(element.name) - \(element.capacity.byteCountFormatted)", action: #selector(diskTapped(_:)), keyEquivalent: "")
                item.tag = index
                item.target = self
            }
        }
        
        statusBarMenu.setSubmenu(subMenu, for: statusItem)
    }
    
    private func preparePreferencesSectionFor(_ statusBarMenu: NSMenu) {
        let loginLaunch = statusBarMenu.addItem(withTitle: "", action: #selector(toggleLaunchOnLogin), keyEquivalent: "")
        loginLaunch.attributedTitle = autoLaunchIsOn ? "Launch RDisk at login".checkmarked : "Launch RDisk at login".crossed
        
        let autocreateDisks = statusBarMenu.addItem(withTitle: "", action: #selector(toggleAutocreateDisks), keyEquivalent: "")
        autocreateDisks.attributedTitle = RAMDiskManager.shared.shouldStoreDiskSetup ? "Auto-create disks on launch".checkmarked : "Auto-create disks on launch".crossed
        
        let about = statusBarMenu.addItem(withTitle: "About RDisk", action: #selector(openAboutPage), keyEquivalent: "")
        
        
        let chooseSyncFolder = statusBarMenu.addItem(withTitle: "Choose Sync Folder", action: #selector(openChooseSyncFolder), keyEquivalent: "")

        loginLaunch.target = self
        autocreateDisks.target = self
        about.target = self
        chooseSyncFolder.target = self
    }
    
    private func prepareQuitSectionFor(_ statusBarMenu: NSMenu) {
        let quit = statusBarMenu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
    }
}

// MARK: - Menu Actions

extension StatusMenu: NSUserInterfaceValidations {
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool { true }
    
    @objc private func createNewDisk() {
        guard let viewController = NSStoryboard(name: "Main", bundle: Bundle(for: CreateNewDiskViewController.self)).instantiateController(withIdentifier: CreateNewDiskViewController.identifier) as? CreateNewDiskViewController else { return }
        presentViewController(viewController)
    }
    
    @objc private func toggleLaunchOnLogin() {
        autoLaunchIsOn.toggle()
        SMLoginItemSetEnabled(StatusMenu.helperBundleName as CFString, autoLaunchIsOn)
        updateStatusBarMenu()
    }
    
    @objc private func toggleAutocreateDisks() {
        RAMDiskManager.shared.shouldStoreDiskSetup.toggle()
        updateStatusBarMenu()
    }
    
    @objc private func openAboutPage() {
        NSApp.orderFrontStandardAboutPanel(self)
    }

    @objc private func openChooseSyncFolder() {
        let controller = ChooseSyncFolderController();
        controller.show();
    }
    
    @objc private func diskTapped(_ menuItem: NSMenuItem) {
        guard RAMDiskManager.shared.mountedRAMDisks.indices.contains(menuItem.tag) else { return }
        let disk = RAMDiskManager.shared.mountedRAMDisks[menuItem.tag]
        
        guard let viewController = NSStoryboard(name: "Main", bundle: Bundle(for: DiskDetailsViewController.self)).instantiateController(withIdentifier: DiskDetailsViewController.identifier) as? DiskDetailsViewController else { return }
        viewController.disk = disk
        presentViewController(viewController)
    }

    @objc private func quitApp() {
        RAMDiskManager.shared.backupAllDrivesIfNeeded(callback: {
            self.showQuitAlert()
        })
    }
    
    @objc private func showQuitAlert() {
        let alert = NSAlert()
        alert.messageText = "Do you want to eject all RAM disks ?"
        alert.informativeText = "When quitting RDisk you can choose whether you want to leave the disks mounted or eject all of them."
        let yesButton = alert.addButton(withTitle: "Quit")
        let ejectButton = alert.addButton(withTitle: "Eject and Quit")
        let cancelButton = alert.addButton(withTitle: "Cancel")
        
        cancelButton.keyEquivalent = "\r"
        yesButton.keyEquivalent = ""
        ejectButton.keyEquivalent = ""
        alert.alertStyle = NSAlert.Style.critical
        
        switch alert.runModal() {
        case .alertFirstButtonReturn: NSApp.terminate(self)
        case .alertSecondButtonReturn:
            RAMDiskManager.shared.mountedRAMDisks.forEach { $0.eject() }
            NSApp.terminate(self)
        default: break
        }
    }
}

// MARK: - Helper Methods

extension StatusMenu: NSWindowDelegate {
    
    private func presentViewController(_ viewController: NSViewController) {
        NSApp.hideInTray(false)
        NSApp.activate(ignoringOtherApps: true)

        guard let controller = NSStoryboard(name: "Main", bundle: Bundle(for: StatusMenu.self)).instantiateController(withIdentifier: "Window") as? NSWindowController else { return }
        guard let window = controller.window else { return }
        window.delegate = self
        window.title = viewController.title ?? ""
        window.contentViewController = viewController
        window.center()
        window.makeKeyAndOrderFront(self)
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard NSApp.windows.contains(where: { $0.className != "NSStatusBarWindow" && $0 != window }) == false else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
