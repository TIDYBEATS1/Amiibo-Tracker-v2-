import SwiftUI

struct AccountView_macOS: View {
    @EnvironmentObject var localAuth: LocalAuthManager
    @State private var showLogoutAlert = false
    
    enum Destination: Hashable {
        case none, friends, support,blocked
    }
    
    @State private var selection: Destination? = nil

    var body: some View {
        NavigationSplitView {
            List {
                AccountHeader()
                    .padding(.vertical)
                
                Section("Account") {
                    Button("Friends") {
                        selection = .friends
                    }
                    Button("Blocked Users"){
                        selection = .blocked
                    }
                    Button("Support") {
                        selection = .support
                    }
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 225)
        } detail: {
            switch selection {
            case .friends:
                FriendsView()
            case .support:
                SupportView()
            case .blocked:
                BlockedUsersView()
            default:
                Text("Select an option from the sidebar")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("Sign out?", isPresented: $showLogoutAlert) {
            Button("Sign Out", role: .destructive) {
                localAuth.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
struct AccountView_macOS_Previews: PreviewProvider {
    static var previews: some View {
        AccountView_macOS()
    }
}
