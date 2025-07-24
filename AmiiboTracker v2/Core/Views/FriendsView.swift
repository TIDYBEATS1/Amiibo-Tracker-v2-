import SwiftUI

struct FriendsView: View {
    @StateObject var viewModel = FriendRequestsViewModel()
    @State private var errorMessage: String?

    private var filteredFriends: [Friend] {
        let blockedIDs = Set(viewModel.blockedUsers.map { $0.userID })
        return viewModel.friends.filter { friend in
            !blockedIDs.contains(friend.userID)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredFriends.isEmpty {
                    Text("You have no friends yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredFriends, id: \.userID) { friend in
                        HStack {
                            Text(friend.username)
                            Spacer()

                            #if os(iOS)
                            if viewModel.blockedUsers.contains(where: { $0.userID == friend.userID }) {
                                Button("Unblock") {
                                    Task {
                                        await handleUnblock(friendID: friend.userID)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                Button("Block") {
                                    Task {
                                        await handleBlock(friendID: friend.userID)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            #endif
                        }
                        #if os(macOS)
                        .contextMenu {
                            Button("Remove Friend") {
                                Task {
                                    await handleRemove(friendID: friend.userID)
                                }
                            }
                            if viewModel.blockedUsers.contains(where: { $0.userID == friend.userID }) {
                                Button("Unblock User") {
                                    Task {
                                        await handleUnblock(friendID: friend.userID)
                                    }
                                }
                            } else {
                                Button("Block User") {
                                    Task {
                                        await handleBlock(friendID: friend.userID)
                                    }
                                }
                            }
                        }
                        #endif
                    }
                    .onDelete(perform: removeFriend)
                }
            }
            .navigationTitle("Friends")
            .task {
                await reloadAll()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func removeFriend(at offsets: IndexSet) {
        let friendsToRemove = offsets.map { filteredFriends[$0] }
        for friend in friendsToRemove {
            Task {
                await handleRemove(friendID: friend.userID)
            }
        }
    }

    private func handleRemove(friendID: String) async {
        do {
            await viewModel.removeFriend(friendID: friendID)
            await reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleBlock(friendID: String) async {
        do {
            try await viewModel.blockUser(userIDToBlock: friendID)
            await reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleUnblock(friendID: String) async {
        do {
            try await viewModel.unblockUser(userIDToUnblock: friendID)
            await reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadAll() async {
        await viewModel.loadFriends()
        await viewModel.loadBlockedUsers()
    }
}
