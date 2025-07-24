import SwiftUI
import FirebaseAuth
import Combine

struct FriendRequestsView: View {
    @StateObject private var viewModel = FriendRequestsViewModel()
    @State private var usernameToAdd = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Friend request input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Send a Friend Request")
                        .font(.headline)

                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(.blue)

                        TextField("Enter username", text: $usernameToAdd)
                            .disableAutocorrection(true)
                            .textFieldStyle(.plain)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondaryBackground)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )

                    Button("Send") {
                        Task { await sendRequest() }
                    }
                    .disabled(usernameToAdd.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackground.opacity(0.7))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal)

                // Feedback messages
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                if let success = successMessage {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                // List of requests
                List {
                    let incomingRequests = viewModel.requests.filter { $0.toUserID == viewModel.currentUserID }
                    let outgoingRequests = viewModel.requests.filter { $0.fromUserID == viewModel.currentUserID }

                    if incomingRequests.isEmpty && outgoingRequests.isEmpty {
                        Text("No pending friend requests.")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        if !incomingRequests.isEmpty {
                            Section(header: Text("Received Requests")) {
                                ForEach(incomingRequests.compactMap { $0.id != nil ? $0 : nil }, id: \.id!) { request in
                                    HStack {
                                        Text(viewModel.usernames[request.fromUserID] ?? "Loading...")
                                        Spacer()
                                        HStack(spacing: 10) {
                                            Button("Accept") {
                                                Task { await viewModel.respond(to: request, accept: true) }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)

                                            Button("Reject") {
                                                Task { await viewModel.respond(to: request, accept: false) }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.red)
                                            .controlSize(.small)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        if !outgoingRequests.isEmpty {
                            Section(header: Text("Sent Requests")) {
                                ForEach(outgoingRequests.compactMap { $0.id != nil ? $0 : nil }, id: \.id!) { request in
                                    HStack {
                                        Text(viewModel.usernames[request.toUserID] ?? "Loading...")
                                        Spacer()
                                        Text("Pending")
                                            .foregroundColor(.gray)
                                            .font(.footnote)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(viewModel.requests.count)
            }
            .navigationTitle("Friend Requests")
            .frame(minWidth: 400, minHeight: 500)
            .onAppear {
                Task { await viewModel.loadRequests() }
            }
        }
    }

    private func sendRequest() async {
        errorMessage = nil
        successMessage = nil

        do {
            try await viewModel.sendFriendRequest(toUsername: usernameToAdd)
            successMessage = "Friend request sent!"
            usernameToAdd = ""
            await viewModel.loadRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestDirectionLabel(for request: FriendRequest) -> String {
        let isIncoming = request.toUserID == viewModel.currentUserID
        if let username = isIncoming ? viewModel.usernames[request.fromUserID] : viewModel.usernames[request.toUserID] {
            return isIncoming ? "From: \(username)" : "To: \(username)"
        } else {
            return isIncoming ? "From: Loading..." : "To: Loading..."
        }
    }
}

extension Color {
    static var secondaryBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor).opacity(0.95)
        #else
        Color.gray.opacity(0.1)
        #endif
    }

    static var cardBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color.white
        #endif
    }
}
