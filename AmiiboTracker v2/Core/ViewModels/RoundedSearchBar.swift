//
//  RoundedSearchBar.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 12/07/2025.
//


import SwiftUI

struct RoundedSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search Amiibo...", text: $text)
                .textFieldStyle(.plain)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(ConditionalGlassButtonStyle())
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .buttonStyle(ConditionalGlassButtonStyle())
    }
}
