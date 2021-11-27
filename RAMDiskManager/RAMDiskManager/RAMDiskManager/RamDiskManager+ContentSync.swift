//
//  RamDiskManager+ContentSync.swift
//  RAMDiskManager
//
//  Created by Yannick Hilber on 27.11.21.
//  Copyright © 2021 Stoyan Stoyanov. All rights reserved.
//

import Foundation
import DiskUtil

// MARK: - Content Sync

extension Array where Element: Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}

enum RestoreError: Error {
    case volumeNameNotFound
    case directoryNotValid(directory: String)
}

public struct Response {
    
    /// The content of the output pipe after the task has been executed.
    public let output: String
    
    /// The content of the error pipe after the task has been executed
    public let error: String
    
    /// The task's exit code.
    public let terminationStatus: Int32
}

extension RAMDiskManager {
    public func getFolder() -> String {
        return UserDefaults.standard.string(forKey: "syncFolder") ?? ""
    }

    public func prepareSyncFolderPersistance() {
        UserDefaults.standard.register(defaults: ["syncFolder" : ""])
    }
    
    public func restoreDiskContentIfNeeded(disk: RAMDisk) {
        guard let path = getPathToBackup(disk: disk) else { return }

        var isDir: ObjCBool = false
        if (FileManager().fileExists(atPath: path, isDirectory: &isDir)) {
            if (isDir.boolValue) {
                do {
                    try syncFolderToDisk(disk: disk, folder: path)
                }
                catch RestoreError.volumeNameNotFound {
                    "Volume Name not found!".showInAlert()
                }
                catch RestoreError.directoryNotValid(let dir) {
                    "\(dir) not valid!".showInAlert()
                }
                catch {
                    "Unexpected Error!".showInAlert()
                }
            }
        }
    }

    public func backupAllDrivesIfNeeded(callback: (() -> Void)? = nil) {
        let syncGroup = DispatchGroup()

        RAMDiskManager.shared.mountedRAMDisks.enumerated().forEach { index, disk in
            guard let path = getPathToBackup(disk: disk) else {
                "Path to Disk \(index) not found!".showInAlert()
                return
            }

            var isDir: ObjCBool = false
            if (FileManager().fileExists(atPath: path, isDirectory: &isDir)) {
                if (isDir.boolValue) {
                    syncGroup.enter()
                    do {
                        try syncDiskToFolder(disk: disk, folder: path, completion: { response in
                            syncGroup.leave()
                        })
                    }
                    catch RestoreError.volumeNameNotFound {
                        "Volume Name not found!".showInAlert()
                    }
                    catch RestoreError.directoryNotValid(let dir) {
                        "\(dir) not valid!".showInAlert()
                    }
                    catch {
                        "Unexpected Error!".showInAlert()
                    }
                }
            }
        }

        syncGroup.notify(queue: .main) {
            callback!()
        }
    }

    public func getPathToBackup(disk: RAMDisk) -> String? {
        let subdirName = disk.name.convertedToSlug();
        var path = getFolder()
        if (path == "") {
            return nil
        }
        path += "/\(subdirName)/";

        return path;
    }

    private func syncFolderToDisk(disk: RAMDisk, folder: String) throws {
        guard let volumeName = disk.rawDisk.volumeName else {
            throw RestoreError.volumeNameNotFound
        };
        let targetPath = "/Volumes/\(volumeName)/"

        var isDir: ObjCBool = false
        if (!FileManager().fileExists(atPath: targetPath, isDirectory: &isDir)) {
            throw RestoreError.directoryNotValid(directory: targetPath)
        }

        if (!isDir.boolValue) {
            throw RestoreError.directoryNotValid(directory: targetPath)
        }
        copySourceToDestination(source: folder, destination: targetPath)
    }

    private func syncDiskToFolder(disk: RAMDisk, folder: String, completion: ((Response) -> ())? = nil) throws {
        guard let volumeName = disk.rawDisk.volumeName else {
            throw RestoreError.volumeNameNotFound
        };
        let sourcePath = "/Volumes/\(volumeName)/"

        var isDir: ObjCBool = false
        if (!FileManager().fileExists(atPath: sourcePath, isDirectory: &isDir)) {
            throw RestoreError.directoryNotValid(directory: sourcePath)
        }

        if (!isDir.boolValue) {
            throw RestoreError.directoryNotValid(directory: sourcePath)
        }
        copySourceToDestination(source: sourcePath, destination: folder, completion: completion)
    }

    private func copySourceToDestination(source: String, destination: String, completion: ((Response) -> ())? = nil) {
        debugPrint("Source:"+source)
        debugPrint("Destination:"+destination)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        task.arguments = ["-xrlptgoEv", "--progress", "--delete", source, destination]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.launch()
        
        task.terminationHandler = { task in
            guard let outputData = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile() else { return }
            guard let errorData = (task.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile() else { return }
            
            let output = String(decoding: outputData, as: UTF8.self)
            let error = String(decoding: errorData, as: UTF8.self)
            if (completion == nil) {
                return
            }

            completion!(Response(output: output, error: error, terminationStatus: task.terminationStatus))
        }
    }
}
