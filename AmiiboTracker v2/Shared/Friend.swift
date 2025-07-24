//
//  Friend.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 21/07/2025.
//

import Foundation


struct Friend: Identifiable, Codable {
    var id: String { userID }
    let userID: String
    let username: String
    let timestamp: Date?
}
