import SwiftUI
import Firebase

struct RootView: View {
    @EnvironmentObject var auth: LocalAuthManager
    @State private var animate = false
    @State private var showLogin = true

    var body: some View {
        Group {
            if auth.isLoadingUserAmiibo {
                // ✅ Loading animation
                VStack(spacing: 30) {
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0.0, to: 0.3)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(animate ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: animate)

                        Text("🎮")
                            .font(.system(size: 36))
                            .scaleEffect(animate ? 1.1 : 0.95)
                            .offset(y: animate ? -4 : 4)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
                    }

                    Text("Loading your Amiibo collection...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .opacity(animate ? 0.6 : 1)
                        .scaleEffect(animate ? 1.02 : 1)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemFill))
                .onAppear {
                    animate = true
                }

            } else if auth.isSignedIn {
                // ✅ Main content view
                ContentView(authManager: auth, service: auth.service)
                    .environmentObject(auth)
                    .environmentObject(auth.service)

            } else {
                // ✅ Show login or register view based on toggle
                if showLogin {
                    LoginView(
                        authManager: auth,
                        service: auth.service,
                        onSwitchToRegister: { showLogin = false }
                    )
                } else {
                    RegisterView(
                        authManager: auth,
                        service: auth.service,
                        onSwitchToLogin: { showLogin = true }
                    )
                }
            }
        }
        .task {
            if auth.isLoadingUserAmiibo {
                await auth.loadUserAmiibo()
            }
        }
    }
}
