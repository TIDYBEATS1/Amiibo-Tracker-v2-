//
//  AuthGateView.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 17/07/2025.
//


import SwiftUI

struct AuthGateView: View {
    @State private var showLogin = true
    @ObservedObject var authManager: LocalAuthManager
    @ObservedObject var service: AmiiboService

    var body: some View {
        VStack {
            if showLogin {
                LoginView(authManager: authManager, service: service, onSwitchToRegister: {
                    showLogin = false
                })
            } else {
                RegisterView(authManager: authManager, service: service, onSwitchToLogin: {
                    showLogin = true
                })
            }
        }
        .animation(.easeInOut, value: showLogin)
        .transition(.slide)
    }
}