import SwiftUI

struct BlockedUsersView: View {
    @StateObject var viewModel = FriendRequestsViewModel()
    @State private var errorMessage: String?
    @State private var userToUnblock: Friend?
    @State private var showUnblockAlert = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.blockedUsers.isEmpty {
                    Text("You haven’t blocked anyone.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.blockedUsers) { user in
                        HStack {
                            Text(user.username)
                            Spacer()
                            Button("Unblock") {
                                userToUnblock = user
                                showUnblockAlert = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
#if os(macOS)
                        .contextMenu {
                            Button("Unblock") {
                                userToUnblock = user
                                showUnblockAlert = true
                            }
                        }
#endif
                    }
                }
            }
            .navigationTitle("Blocked Users")
            .task {
                await viewModel.loadBlockedUsers()
            }
            .alert("Unblock \(userToUnblock?.username ?? "User")?",
                   isPresented: $showUnblockAlert,
                   actions: {
                       Button("Cancel", role: .cancel) { }
                       Button("Unblock", role: .destructive) {
                           Task {
                               if let user = userToUnblock {
                                   do {
                                       try await viewModel.unblockUser(userIDToUnblock: user.userID)
                                   } catch {
                                       errorMessage = error.localizedDescription
                                   }
                               }
                               userToUnblock = nil
                           }
                       }
                   },
                   message: {
                       Text("Are you sure you want to unblock \(userToUnblock?.username ?? "this user")?")
                   })
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
