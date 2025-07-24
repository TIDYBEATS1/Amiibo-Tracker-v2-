import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class FriendRequestsViewModel: ObservableObject {
    @Published var requests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var usernames: [String: String] = [:]
    @Published var receivedRequests: [FriendRequest] = []
    @Published var statusMessage: String? = nil
    @Published var currentUserID: String? = Auth.auth().currentUser?.uid
    @Published var friends: [Friend] = [] // Changed from [String] to [Friend]
    @Published var blockedUsers: [Friend] = []
    
    private let db = Firestore.firestore()

    func loadFriends() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("users")
                .document(currentUserID)
                .collection("friends")
                .getDocuments()

            let fetchedFriends = snapshot.documents.compactMap { doc in
                try? doc.data(as: Friend.self)
            }

            self.friends = fetchedFriends
        } catch {
            print("Failed to load friends: \(error)")
        }
    }
    func blockUser(userIDToBlock: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let blockRef = db.collection("users").document(currentUserID).collection("blockedUsers").document(userIDToBlock)

        try await blockRef.setData([
            "timestamp": FieldValue.serverTimestamp()
        ])

        // Remove friend if exists
        try await removeFriend(friendID: userIDToBlock)

        // Optionally remove any pending friend requests between users
        try await removePendingFriendRequests(between: currentUserID, and: userIDToBlock)

        await loadBlockedUsers()
        await loadFriends()  // Refresh friend list
    }
    private func removePendingFriendRequests(between user1: String, and user2: String) async throws {
        let requestsQuery = db.collection("friend_requests")
            .whereField("status", isEqualTo: "pending")
            .whereField("fromUserID", in: [user1, user2])
            .whereField("toUserID", in: [user1, user2])
        
        let snapshot = try await requestsQuery.getDocuments()
        for doc in snapshot.documents {
            let data = doc.data()
            let fromUserID = data["fromUserID"] as? String ?? ""
            let toUserID = data["toUserID"] as? String ?? ""
            
            // Only remove requests where users are opposite sides
            if (fromUserID == user1 && toUserID == user2) || (fromUserID == user2 && toUserID == user1) {
                try await db.collection("friend_requests").document(doc.documentID).delete()
            }
        }
    }
    func unblockUser(userIDToUnblock: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let blockRef = db.collection("users").document(currentUserID).collection("blockedUsers").document(userIDToUnblock)

        try await blockRef.delete()

        await loadBlockedUsers()
    }

    func loadBlockedUsers() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("users")
                .document(currentUserID)
                .collection("blockedUsers")
                .getDocuments()

            var blockedIDs: [String] = []
            for doc in snapshot.documents {
                blockedIDs.append(doc.documentID)
            }

            var loadedUsers: [Friend] = []

            // Fetch usernames for all blocked userIDs in parallel
            await withTaskGroup(of: Friend?.self) { group in
                for userID in blockedIDs {
                    group.addTask {
                        do {
                            let userDoc = try await self.db.collection("users").document(userID).getDocument()
                            let username = userDoc.data()?["username"] as? String ?? "Unknown"
                            let timestamp = (snapshot.documents.first(where: { $0.documentID == userID })?.data()["timestamp"] as? Timestamp)?.dateValue()
                            return Friend(userID: userID, username: username, timestamp: timestamp)
                        } catch {
                            return nil
                        }
                    }
                }

                for await friend in group {
                    if let friend = friend {
                        loadedUsers.append(friend)
                    }
                }
            }

            self.blockedUsers = loadedUsers
        } catch {
            print("❌ Failed to load blocked users: \(error)")
        }
    }
    func removeFriend(friendID: String) async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(currentUserID)
                .collection("friends").document(friendID).delete()

            try await db.collection("users").document(friendID)
                .collection("friends").document(currentUserID).delete()

            await loadFriends()
        } catch {
            print("Failed to remove friend: \(error)")
        }
    }

    func fetchUsername(for uid: String) async throws -> String {
        let doc = try await db.collection("users").document(uid).getDocument()
        return doc.get("username") as? String ?? "Unknown"
    }

    func respond(to request: FriendRequest, accept: Bool) async {
        guard let requestID = request.id else { return }

        do {
            if accept {
                let currentUserID = Auth.auth().currentUser?.uid ?? ""
                let otherUserID = request.fromUserID == currentUserID ? request.toUserID : request.fromUserID

                let currentUserRef = db.collection("users").document(currentUserID).collection("friends").document(otherUserID)
                let otherUserRef = db.collection("users").document(otherUserID).collection("friends").document(currentUserID)

                let currentUsername = try await fetchUsername(for: currentUserID)
                let otherUsername = try await fetchUsername(for: otherUserID)

                try await currentUserRef.setData([
                    "userID": otherUserID,
                    "username": otherUsername,
                    "timestamp": FieldValue.serverTimestamp()
                ])

                try await otherUserRef.setData([
                    "userID": currentUserID,
                    "username": currentUsername,
                    "timestamp": FieldValue.serverTimestamp()
                ])
            }

            try await db.collection("friend_requests").document(requestID).delete()
            await loadRequests()
            await loadFriends()
        } catch {
            print("Error responding to request: \(error.localizedDescription)")
        }
    }

    func loadRequests() async {
        guard let currentUser = Auth.auth().currentUser else { return }

        do {
            let incomingSnapshot = try await db.collection("friend_requests")
                .whereField("toUserID", isEqualTo: currentUser.uid)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()

            let incomingRequests = try incomingSnapshot.documents.map {
                try $0.data(as: FriendRequest.self)
            }

            let sentSnapshot = try await db.collection("friend_requests")
                .whereField("fromUserID", isEqualTo: currentUser.uid)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()

            let sentRequests = try sentSnapshot.documents.map {
                try $0.data(as: FriendRequest.self)
            }

            let combinedRequests = incomingRequests + sentRequests
            let allUserIDs = Set(combinedRequests.flatMap { [$0.fromUserID, $0.toUserID] })
            await preloadUsernames(for: allUserIDs)

            self.requests = combinedRequests
        } catch {
            print("Error loading friend requests: \(error)")
        }
    }

    private func preloadUsernames(for userIDs: Set<String>) async {
        await withTaskGroup(of: (String, String?).self) { group in
            for userID in userIDs where usernames[userID] == nil {
                group.addTask {
                    do {
                        let doc = try await self.db.collection("users").document(userID).getDocument()
                        let username = doc.data()?["username"] as? String
                        return (userID, username)
                    } catch {
                        return (userID, nil)
                    }
                }
            }

            for await (userID, username) in group {
                if let username = username {
                    usernames[userID] = username
                }
            }
        }
    }

    func sendFriendRequest(toUsername username: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }

        // Get recipient user ID
        let querySnapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()

        guard let doc = querySnapshot.documents.first else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }

        let friendUID = doc.documentID

        // Prevent sending to self
        if friendUID == currentUID {
            throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "You cannot send a friend request to yourself"])
        }

        // Check if user already sent *you* a friend request — auto-accept
        let incomingRequestSnapshot = try await db.collection("friend_requests")
            .whereField("fromUserID", isEqualTo: friendUID)
            .whereField("toUserID", isEqualTo: currentUID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()

        if let incomingRequest = incomingRequestSnapshot.documents.first {
            let request = try incomingRequest.data(as: FriendRequest.self)
            await respond(to: request, accept: true)
            return
        }

        // Check if you already sent them a request
        let existingRequestsSnapshot = try await db.collection("friend_requests")
            .whereField("fromUserID", isEqualTo: currentUID)
            .whereField("toUserID", isEqualTo: friendUID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()

        if !existingRequestsSnapshot.documents.isEmpty {
            throw NSError(domain: "", code: 409, userInfo: [NSLocalizedDescriptionKey: "Friend request already sent"])
        }

        // Otherwise, send a new friend request
        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserID: currentUID,
            toUserID: friendUID,
            status: "pending",
            timestamp: Date()
        )

        guard let requestID = request.id else {
            print("❌ Friend request ID is nil.")
            return
        }

        try db.collection("friend_requests").document(requestID).setData(from: request)
    }
    func loadSentRequests() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("friend_requests")
                .whereField("fromUserID", isEqualTo: currentUserID)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()

            self.sentRequests = snapshot.documents.compactMap {
                try? $0.data(as: FriendRequest.self)
            }
        } catch {
            print("Failed to load sent requests:", error)
        }
    }
}
