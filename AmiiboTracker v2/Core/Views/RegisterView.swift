import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
typealias PlatformColor = NSColor
#endif

struct RegisterView: View {
    @ObservedObject var authManager: LocalAuthManager
    @ObservedObject var service: AmiiboService
    var onSwitchToLogin: () -> Void

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var currentIconIndex = 0

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case username, email, password
    }
    let icons = ["mario", "bayonetta", "detective-pikachu","pauline","bowser"] // replace with your actual icon names
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: - Brand / Logo
            Image(icons[currentIconIndex])
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .shadow(radius: 6)
                            .transition(.opacity.combined(with: .scale))
                            .id(currentIconIndex)

            Text("Create Account")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            VStack(spacing: 24) {
                // Username Field
                FloatingTextField<Field>(
                    text: $username,
                    title: "Username",
                    keyboardType: .default,
                    isSecure: false,
                    focusedField: $focusedField,
                    fieldIdentifier: .username
                )
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .email
                }

                // Email Field
                FloatingTextField<Field>(
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

                // Password Field
                FloatingTextField<Field>(
                    text: $password,
                    title: "Password",
                    keyboardType: .default,
                    isSecure: true,
                    focusedField: $focusedField,
                    fieldIdentifier: .password
                )
                .submitLabel(.go)
                .onSubmit {
                    Task { await register() }
                }
            }
            .padding(.horizontal, 32)

            // Error message area
            if !alertMessage.isEmpty {
                Text(alertMessage)
                    .font(.callout)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Register Button
            Button {
                Task { await register() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.1)
                            .padding(.trailing, 8)
                    }
                    Text("Create Account")
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
            .disabled(username.isEmpty || email.isEmpty || password.isEmpty || isLoading)
            .padding(.horizontal, 32)

            // Switch to Login Button
            Button("Already have an account? Sign In") {
                onSwitchToLogin()
            }
            .font(.footnote)
            .foregroundColor(AppColors.amiiboRed)
            .underline()
            .padding(.top, 4)

            Spacer()
        }
        .padding(.vertical)
        
        
        .onTapGesture {
            hideKeyboard()
        }
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
        .alert("Registration Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    func register() async {
        guard !username.isEmpty && !email.isEmpty && !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }

        isLoading = true
        alertMessage = ""

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Set display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = username
            try await changeRequest.commitChanges()

            // Save username to Firestore
            let userRef = Firestore.firestore().collection("users").document(result.user.uid)
            try await userRef.setData([
                "username": username,
                "email": email,
                "createdAt": FieldValue.serverTimestamp()
            ])

            await authManager.signIn(with: result.user)
        } catch {
            alertMessage = "Registration failed: \(error.localizedDescription)"
            showAlert = true
        }

        isLoading = false
    }
}
#Preview {
    RegisterView(
        authManager: LocalAuthManager(service: AmiiboService()),
        service: AmiiboService(),
        onSwitchToLogin: { }
    )
}
