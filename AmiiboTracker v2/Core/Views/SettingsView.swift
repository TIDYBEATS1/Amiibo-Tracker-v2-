import SwiftUI
import UserNotifications
import FirebaseAuth

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @StateObject var localAuth: LocalAuthManager
    @EnvironmentObject var amiiboService: AmiiboService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showAccountView = false

    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("offlineMode") private var offlineMode = false
    @State private var showFriendRequests = false
    @State private var showResetAlert = false
    @State private var showCacheClearedAlert = false
    @State private var showNotificationAlert = false
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account")) {
                    NavigationLink(destination: AccountView()
                        .environmentObject(localAuth)
                        .environmentObject(amiiboService)) {
                        Label("Manage Account", systemImage: "person.crop.circle")
                    }
                    
                    Button {
                        showFriendRequests = true
                    } label: {
                        SettingsButtonLabel(icon: "person.crop.circle.badge.questionmark", title: "Friend Requests")
                    }
                }

                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themeManager.selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Notifications")) {
                    Toggle(isOn: Binding(get: {
                        notificationsEnabled
                    }, set: { newValue in
                        if newValue {
                            requestNotificationPermission()
                        } else {
                            notificationsEnabled = false
                        }
                    })) {
                        Label("Enable Notifications", systemImage: "bell.fill")
                    }

                    if notificationsEnabled {
                        Text("Notifications are enabled ✅")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Notifications are disabled or permission not granted.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    #if DEBUG
                    Button {
                        sendTestNotification()
                    } label: {
                        SettingsButtonLabel(icon: "paperplane.fill", title: "Send Test Notification")
                    }
                    #endif
                }

                Section(header: Text("Advanced")) {
                    Toggle("Offline Mode", isOn: $offlineMode)

                    Button {
                        amiiboService.clearCacheAndRefetch()
                        showCacheClearedAlert = true
                    } label: {
                        SettingsButtonLabel(icon: "trash.fill", title: "Clear Cache")
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        SettingsButtonLabel(icon: "exclamationmark.triangle.fill", title: "Reset App Data", destructive: true)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showFriendRequests) {
                FriendRequestsView()
            }
            .alert("Cache Cleared", isPresented: $showCacheClearedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The cache has been successfully cleared.")
            }
            .alert("Are you sure?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    amiiboService.resetAppData()
                    localAuth.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all data and sign you out.")
            }
            .alert("Notification Sent!", isPresented: $showNotificationAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert("Permission Needed", isPresented: $showPermissionAlert) {
                #if os(iOS)
                Button("Go to Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #elseif os(macOS)
                Button("Enable Notifications") {
                    // macOS-specific permission handling
                }
                #endif
            }
        }
    }

    // MARK: - Helpers
#if os(macOS)
typealias AccountView = AccountView_macOS
#else
typealias AccountView = AccountView_iOS
#endif
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationsEnabled = granted
                if !granted {
                    showPermissionAlert = true
                }
            }
        }
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from AmiiboTracker."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                DispatchQueue.main.async {
                    showNotificationAlert = true
                }
            }
        }
    }
}

struct SettingsButtonLabel: View {
    let icon: String
    let title: String
    var destructive: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(destructive ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(destructive ? .red : .accentColor)
                )
            Text(title)
                .foregroundColor(destructive ? .red : .primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}
