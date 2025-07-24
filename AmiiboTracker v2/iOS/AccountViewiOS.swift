import SwiftUI

struct AccountView_iOS: View {
    @EnvironmentObject var localAuth: LocalAuthManager
    @State private var showLogoutAlert = false
    @State private var showChangeUsername = false
    @StateObject private var viewModel = AccountViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AccountHeader()
                }
                Section("Profile") {
                    TextField("Username", text: $viewModel.username)

                    Button("Update Username") {
                        Task {
                            await viewModel.updateProfile()
                        }
                    }
                    .disabled(viewModel.username.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let success = viewModel.successMessage {
                        Text(success).foregroundColor(.green)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error).foregroundColor(.red)
                    }
                }

                Section("Account") {
                    NavigationLink("Friends", destination: FriendsView())
                    NavigationLink("Blocked Users", destination: BlockedUsersView())
                    NavigationLink("Support", destination: SupportView())
                    Button("Change Username") {
                        showChangeUsername = true
                    }
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Account")
            .alert("Sign out?", isPresented: $showLogoutAlert) {
                Button("Sign Out", role: .destructive) {
                    localAuth.signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
