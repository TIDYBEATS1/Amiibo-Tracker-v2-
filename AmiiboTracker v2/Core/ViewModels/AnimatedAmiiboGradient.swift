//
//  AnimatedAmiiboGradient.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 17/07/2025.
//


import SwiftUI

struct AnimatedAmiiboGradient: View {
    @State private var animate = false

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color("AmiiboRed"), Color("AmiiboYellow"), Color("AmiiboBlue")]),
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate)
        .onAppear { animate = true }
    }
}