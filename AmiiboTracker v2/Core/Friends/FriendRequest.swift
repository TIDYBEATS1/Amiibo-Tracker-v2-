// FriendRequest.swift

import Foundation
import FirebaseFirestore

struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String? // Firestore doc ID
    var fromUserID: String
    var toUserID: String
    var status: String // e.g., "pending", "accepted", "rejected"
    @ServerTimestamp var timestamp: Date?
    
    enum Status: String, Codable {
        case pending, accepted, rejected
    }
}
