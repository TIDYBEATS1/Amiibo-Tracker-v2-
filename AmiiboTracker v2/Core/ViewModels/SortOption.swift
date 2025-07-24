//
//  SortOption.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 20/07/2025.
//


// SortOption.swift (shared across macOS and iOS)

import Foundation


enum SortOption: String, CaseIterable {
    case relevance
    case releaseOldest
    case releaseNewest
    case owned

    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .releaseOldest: return "Oldest"
        case .releaseNewest: return "Newest"
        case .owned: return "Owned"
        }
    }
}
