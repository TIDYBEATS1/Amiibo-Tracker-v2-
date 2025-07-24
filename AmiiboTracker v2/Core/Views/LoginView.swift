import SwiftUI
import FirebaseAuth
import Combine

struct LoginView: View {
    @ObservedObject var authManager: LocalAuthManager
    @ObservedObject var service: AmiiboService
    var onSwitchToRegister: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, password
    }

    @State private var showContent = false
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    let icons = ["mario", "bayonetta", "detective-pikachu","pauline","bowser"] // replace with your actual icon names
        @State private var currentIconIndex = 0

        var body: some View {
            VStack(spacing: 32) {
                Spacer()

                Image(icons[currentIconIndex])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                                .shadow(radius: 6)
                                .transition(.opacity.combined(with: .scale))
                                .id(currentIconIndex)

                Text("AmiiboTracker")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .onReceive(timer) { _ in
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    var newIndex: Int
                                    repeat {
                                        newIndex = Int.random(in: 0..<icons.count)
                                    } while newIndex == currentIconIndex
                                    currentIconIndex = newIndex
                                }
                            }

            VStack(spacing: 24) {
                FloatingTextField(
                    text: $email,
                    title: "Email",
                    keyboardType: .emailAddress,
                    isSecure: false,
                    focusedField: $focusedField,
                    fieldIdentifier: .email
                )
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }

                FloatingTextField(
                    text: $password,
                    title: "Password",
                    keyboardType: .default,
                    isSecure: true,
                    focusedField: $focusedField,
                    fieldIdentifier: .password
                )
                .submitLabel(.go)
                .onSubmit {
                    Task { await signIn() }
                }
            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.8).delay(0.4), value: showContent)

            // Error message with fade in/out
            if !alertMessage.isEmpty {
                Text(alertMessage)
                    .font(.callout)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: alertMessage)
            }

            // Sign In Button with loading animation
            Button(action: {
                Task { await signIn() }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.1)
                            .padding(.trailing, 8)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.4), value: isLoading)
                    }
                    Text("Sign In")
                        .buttonStyle(ConditionalGlassButtonStyle())
                        .fontWeight(.semibold)
                        .font(.title3)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.amiiboRed)
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: AppColors.amiiboRed.opacity(0.6), radius: 8, x: 0, y: 4)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.8).delay(0.5), value: showContent)

            // Forgot Password & Register Links
            HStack {
                Button("Forgot Password?") {
                    Task { await resetPassword() }
                }
                .buttonStyle(ConditionalGlassButtonStyle())
                .font(.footnote)
                .foregroundColor(AppColors.amiiboRed)
                .underline()

                Spacer()

                Button("Register") {
                    onSwitchToRegister()
                }
                .font(.footnote)
                .foregroundColor(AppColors.amiiboRed)
                .underline()
                .buttonStyle(ConditionalGlassButtonStyle())

            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.8).delay(0.6), value: showContent)
                
            Spacer()
        }
            .padding(.vertical)
            .background(
                Group {
                    #if os(iOS)
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                    #elseif os(macOS)
                    Color(NSColor.windowBackgroundColor)
                        .ignoresSafeArea()
                    #else
                    Color.white
                        .ignoresSafeArea()
                    #endif
                }
            )
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            // Trigger fade-in animation when view appears
            showContent = true
        }
        .alert("Login Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
                .buttonStyle(ConditionalGlassButtonStyle())
        } message: {
            Text(alertMessage)
        }
    }

    func signIn() async {
        guard !email.isEmpty && !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }
        isLoading = true
        alertMessage = ""
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await authManager.signIn(with: result.user)
        } catch {
            alertMessage = "Sign-in failed: \(error.localizedDescription)"
            showAlert = true
        }
        isLoading = false
    }

    func resetPassword() async {
        guard !email.isEmpty else {
            alertMessage = "Enter your email to reset password."
            showAlert = true
            return
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            alertMessage = "Password reset email sent to \(email)."
            showAlert = true
        } catch {
            alertMessage = "Reset failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
struct AppColors {
    static let amiiboRed = Color(red: 0.89, green: 0.15, blue: 0.13)
}
extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}
