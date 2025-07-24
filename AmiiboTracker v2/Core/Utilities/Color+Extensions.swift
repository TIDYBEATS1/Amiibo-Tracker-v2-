//
//  Color+Extensions.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 12/07/2025.
//

import SwiftUI

extension Color {
    static var secondarySystemBackground: Color {
        #if os(iOS) || os(tvOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor).opacity(0.5)
        #else
        return Color.gray.opacity(0.1) // fallback
        #endif
    }
}
