//
//  FriendsViewModel.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 21/07/2025.
//


import Firebase
import FirebaseFirestore
import Combine
import FirebaseAuth
@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    private var listener: ListenerRegistration?

    func loadFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore().collection("users").document(uid).collection("friends")

        listener?.remove() // Stop any previous listeners
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let documents = snapshot?.documents else { return }

            self.friends = documents.compactMap { doc in
                let data = doc.data()
                let userID = data["userID"] as? String ?? doc.documentID
                let username = data["username"] as? String ?? "Unknown"
                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
                return Friend(userID: userID, username: username, timestamp: timestamp)
            }
        }
    }

    deinit {
        listener?.remove()
    }
}
