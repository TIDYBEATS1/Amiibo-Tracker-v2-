//
//  ConditionalGlassButtonStyle.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 17/07/2025.
//

import SwiftUI

struct ConditionalGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                configuration.label
                    .buttonStyle(.glass)
            } else {
                configuration.label
                    .buttonStyle(.borderless)
            }
        }
    }
}
