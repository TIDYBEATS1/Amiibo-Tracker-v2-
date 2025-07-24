//
//  ChangeUsernameSheet.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 24/07/2025.
//

import SwiftUI

struct ChangeUsernameSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AccountViewModel()
    @State private var newUsername = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("New Username") {
                    TextField("Enter new username", text: $newUsername)
                        .disableAutocorrection(true)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                if let success = viewModel.successMessage {
                    Text(success)
                        .foregroundColor(.green)
                }
            }
            .navigationTitle("Change Username")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            viewModel.username = newUsername
                            await viewModel.updateProfile()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
