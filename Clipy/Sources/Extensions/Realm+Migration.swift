//
//  Realm+Migration.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/10/16.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import RealmSwift

extension Realm {
    static func migration() {
        let config = Realm.Configuration(schemaVersion: 7, migrationBlock: { migration, oldSchemaVersion in
            if oldSchemaVersion <= 2 {
                // Add identifier in CPYSnippet
                migration.enumerateObjects(ofType: CPYSnippet.className()) { _, newObject in
                    newObject!["identifier"] = NSUUID().uuidString
                }
            }
            if oldSchemaVersion <= 4 {
                // Add identifier in CPYFolder
                migration.enumerateObjects(ofType: CPYFolder.className()) { _, newObject in
                    newObject!["identifier"] = NSUUID().uuidString
                }
            }
            if oldSchemaVersion <= 5 {
                // Update RealmObjc to RealmSwift
                migration.enumerateObjects(ofType: CPYClip.className(), { oldObject, newObject in
                    newObject!["dataPath"] = oldObject!["dataPath"]
                    newObject!["title"] = oldObject!["title"]
                    newObject!["dataHash"] = oldObject!["dataHash"]
                    newObject!["primaryType"] = oldObject!["primaryType"]
                    newObject!["updateTime"] = oldObject!["updateTime"]
                    newObject!["thumbnailPath"] = oldObject!["thumbnailPath"]
                })
                migration.enumerateObjects(ofType: CPYSnippet.className(), { oldObject, newObject in
                    newObject!["index"] = oldObject!["index"]
                    newObject!["enable"] = oldObject!["enable"]
                    newObject!["title"] = oldObject!["title"]
                    newObject!["content"] = oldObject!["content"]
                    if oldSchemaVersion >= 3 {
                        newObject!["identifier"] = oldObject!["identifier"]
                    }
                })
                migration.enumerateObjects(ofType: CPYFolder.className(), { oldObject, newObject in
                    newObject!["index"] = oldObject!["index"]
                    newObject!["enable"] = oldObject!["enable"]
                    newObject!["title"] = oldObject!["title"]
                    if oldSchemaVersion >= 5 {
                        newObject!["identifier"] = oldObject!["identifier"]
                    }
                })
            }
        })
        Realm.Configuration.defaultConfiguration = config
        openRealmOrResetIncompatibleStore(using: config)
    }

    private static func openRealmOrResetIncompatibleStore(using config: Realm.Configuration) {
        do {
            _ = try Realm()
        } catch {
            guard shouldResetStore(for: error), let fileURL = config.fileURL else {
                fatalError("Failed to open Realm: \(error)")
            }

            do {
                try backupIncompatibleStore(at: fileURL)
                _ = try Realm()
            } catch {
                fatalError("Failed to recover incompatible Realm store: \(error)")
            }
        }
    }

    private static func shouldResetStore(for error: Swift.Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "io.realm" && nsError.code == 16
    }

    private static func backupIncompatibleStore(at fileURL: URL) throws {
        let fileManager = FileManager.default
        let baseDirectory = fileURL.deletingLastPathComponent()
        let backupsDirectory = baseDirectory.appendingPathComponent("RealmBackups", isDirectory: true)
        try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDirectory = backupsDirectory.appendingPathComponent("incompatible-\(timestamp)", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let relatedURLs = [
            fileURL,
            fileURL.appendingPathExtension("lock"),
            fileURL.appendingPathExtension("note"),
            fileURL.appendingPathExtension("management"),
            fileURL.appendingPathExtension("backup-log")
        ]

        for relatedURL in relatedURLs {
            guard fileManager.fileExists(atPath: relatedURL.path) else { continue }
            let destinationURL = backupDirectory.appendingPathComponent(relatedURL.lastPathComponent, isDirectory: false)

            do {
                try fileManager.moveItem(at: relatedURL, to: destinationURL)
            } catch {
                if relatedURL == fileURL {
                    throw error
                }
            }
        }
    }
}
