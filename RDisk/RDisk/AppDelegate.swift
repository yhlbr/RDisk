//
//  AppDelegate.swift
//  RDisk
//
//  Created by Stoyan Stoyanov on 18/12/2019.
//  Copyright © 2019 Stoyan Stoyanov. All rights reserved.
//

import Cocoa
import RAMDiskManager


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.hideInTray(true)
        
        RAMDiskManager.shared.restoreDiskSetup()
        RAMDiskManager.shared.prepareShouldStoreDiskSetupPersistance()
        RAMDiskManager.shared.prepareSyncFolderPersistance()
        StatusMenu.shared.show()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
