//
//  AmiiboLoadingView.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 14/07/2025.
//


import SwiftUI

struct AmiiboLoadingView: View {
    @State private var isGlowing = false
    @State private var isBouncing = false

    var body: some View {
        ZStack {
            // Background Glow
            RadialGradient(
                gradient: Gradient(colors: [.accentColor.opacity(0.3), .clear]),
                center: .center,
                startRadius: 10,
                endRadius: isGlowing ? 300 : 200
            )
            .ignoresSafeArea()
            .scaleEffect(isGlowing ? 1.2 : 0.9)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isGlowing)

            VStack(spacing: 30) {
                // Bouncing NFC-style icons
                HStack(spacing: 20) {
                    ForEach(0..<3) { i in
                        Image(systemName: "wave.3.right.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.accentColor)
                            .offset(y: isBouncing ? -10 : 10)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(i) * 0.2),
                                value: isBouncing
                            )
                    }
                }

                // Loading Text
                Text("Scanning for Amiibo…")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(isBouncing ? 1 : 0.5)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isBouncing)
            }
        }
        .onAppear {
            isGlowing = true
            isBouncing = true
        }
    }
}