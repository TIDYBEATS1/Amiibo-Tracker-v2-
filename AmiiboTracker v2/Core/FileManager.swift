//
//  FileManager.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 12/07/2025.
//

import Foundation

extension FileManager {
    static var amiiboImagesCacheURL: URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folderURL = cachesDirectory.appendingPathComponent("AmiiboImages", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        return folderURL
    }
}
