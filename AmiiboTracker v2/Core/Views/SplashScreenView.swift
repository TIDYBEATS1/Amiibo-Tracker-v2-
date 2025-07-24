//
//  SplashScreenView.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 14/07/2025.
//


import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        VStack {
            ProgressView("Loading AmiiboTracker...")
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemFill))
    }
}
