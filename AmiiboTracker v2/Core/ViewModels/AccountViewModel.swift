//
//  AccountViewModel.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 23/07/2025.
//


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
@MainActor
class AccountViewModel: ObservableObject {
    @Published var user: User?
    @Published var username: String = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let db = Firestore.firestore()

    init() {
        self.user = Auth.auth().currentUser
        fetchUserProfile()
    }

    func fetchUserProfile() {
        guard let user = user else { return }

        // Try Firebase Auth displayName
        if let displayName = user.displayName, !displayName.isEmpty {
            self.username = displayName
        }

        // Then load Firestore username
        let userDoc = db.collection("users").document(user.uid)
        userDoc.getDocument { document, error in
            if let document = document, document.exists,
               let firestoreUsername = document.data()?["username"] as? String {
                self.username = firestoreUsername
            } else if let error = error {
                print("Failed to fetch username from Firestore: \(error.localizedDescription)")
            }
        }
    }

    func updateProfile() async {
        guard let user = user else { return }
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        guard !trimmedUsername.isEmpty else {
            errorMessage = "Username cannot be empty."
            return
        }

        errorMessage = nil
        successMessage = nil

        do {
            // 1. Update Auth displayName
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = trimmedUsername
            try await changeRequest.commitChanges()

            // 2. Update Firestore document
            let userDoc = db.collection("users").document(user.uid)
            try await userDoc.setData(["username": trimmedUsername], merge: true)

            self.successMessage = "Username updated!"
            print("✅ Username updated in Auth & Firestore.")

        } catch {
            self.errorMessage = "Failed to update: \(error.localizedDescription)"
        }
    }
}
