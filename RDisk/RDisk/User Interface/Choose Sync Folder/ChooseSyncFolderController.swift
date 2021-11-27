//
//  ChooseSyncFolderController.swift
//  RDisk
//
//  Created by Yannick Hilber on 27.11.21.
//  Copyright © 2021 Stoyan Stoyanov. All rights reserved.
//

import Foundation
import AppKit

class ChooseSyncFolderController {
    public func show() {
        showFolderSelection()
    }
    
    private func showFolderSelection() -> Void {
        let dialog = NSOpenPanel();

        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = true;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = true;
        dialog.canChooseFiles = false;
        dialog.canCreateDirectories = true;

        dialog.begin(completionHandler: { (response) -> Void in
            if (response == NSApplication.ModalResponse.OK) {
                let result = dialog.url
                if (result != nil) {
                    let path: String = result!.path
                    ChooseSyncFolderController.storeFolder(url: path)
                }
            }
        });
    }

    private static func storeFolder(url: String) {
        UserDefaults.standard.set(url, forKey: "syncFolder")
        UserDefaults.standard.synchronize()
        let alert = NSAlert()
        alert.messageText = "Saved Disk Sync Folder"
        alert.runModal()
    }
}
