// FriendService.swift

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
@MainActor
class FriendService: ObservableObject {
    private let db = Firestore.firestore()
    private let friendRequestsCollection = "friend_requests"
    
    /// Send a friend request to a user by their UID
    func sendFriendRequest(to targetUserID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        if currentUserID == targetUserID {
            throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot send request to yourself"])
        }
        
        // Check if a pending request already exists (optional)
        let existingRequestsQuery = try await db.collection(friendRequestsCollection)
            .whereField("fromUserID", isEqualTo: currentUserID)
            .whereField("toUserID", isEqualTo: targetUserID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        if !existingRequestsQuery.documents.isEmpty {
            throw NSError(domain: "", code: 409, userInfo: [NSLocalizedDescriptionKey: "Friend request already sent"])
        }
        
        // Create new friend request
        let newRequest = FriendRequest(
            fromUserID: currentUserID,
            toUserID: targetUserID,
            status: FriendRequest.Status.pending.rawValue
        )
        
        _ = try await db.collection(friendRequestsCollection).addDocument(from: newRequest)
    }
    
    /// Load all pending friend requests for current user
    func loadFriendRequests() async throws -> [FriendRequest] {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let snapshot = try await db.collection(friendRequestsCollection)
            .whereField("toUserID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: FriendRequest.Status.pending.rawValue)
            .getDocuments()
        
        return try snapshot.documents.compactMap {
            try $0.data(as: FriendRequest.self)
        }
    }
    
    /// Respond to a friend request (accept or reject)
    func respond(to request: FriendRequest, accept: Bool) async throws {
        guard let requestId = request.id else {
            throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid request ID"])
        }
        
        let status = accept ? FriendRequest.Status.accepted.rawValue : FriendRequest.Status.rejected.rawValue
        
        try await db.collection(friendRequestsCollection)
            .document(requestId)
            .updateData(["status": status])
        
        if accept {
            // Add to each other's friends list
            try await db.collection("users").document(request.fromUserID)
                .collection("friends").document(request.toUserID).setData([:])
            
            try await db.collection("users").document(request.toUserID)
                .collection("friends").document(request.fromUserID).setData([:])
        }
    }
}
