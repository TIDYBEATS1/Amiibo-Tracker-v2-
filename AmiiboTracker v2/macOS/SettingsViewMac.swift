//
//  SettingsViewMac.swift
//  AmiiboTracker v2
//
//  Created by Sam Stanwell on 21/07/2025.
//

import SwiftUI
import UserNotifications

#if os(macOS)

struct SettingsViewMac: View {
    @StateObject var localAuth: LocalAuthManager
    @EnvironmentObject var amiiboService: AmiiboService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selection: String? = "Account"
    @State private var showAccountView = false
    @State private var showFriendRequests = false
    @State private var showResetAlert = false
    @State private var showCacheClearedAlert = false
    @State private var showNotificationAlert = false
    @State private var showPermissionAlert = false

    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("offlineMode") private var offlineMode = false

    let sections = ["Account", "Appearance", "Notifications", "Advanced"]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(sections, id: \.self) { section in
                    Label(section, systemImage: iconName(for: section))
                        .tag(section)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Settings")
            .frame(minWidth: 180)
        } detail: {
            switch selection {
            case "Account": accountSection
            case "Appearance": appearanceSection
            case "Notifications": notificationsSection
            case "Advanced": advancedSection
            default:
                Text("Select a section from the sidebar.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .sheet(isPresented: $showAccountView) {
            AccountView_macOS()
                .environmentObject(localAuth)
                .environmentObject(amiiboService)
                .frame(width: 650, height: 600)
        }
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
            Button("Enable Notifications") {
                requestNotificationPermission()
            }
        }
    }

    // MARK: - Section Views

    var accountSection: some View {
        sectionLayout {
            settingsButton("Manage Account", systemImage: "gearshape") {
                showAccountView = true
            }

            settingsButton("Friend Requests", systemImage: "person.2.fill") {
                showFriendRequests = true
            }
        } title: {
            Label("Account", systemImage: "person.crop.circle")
        }
    }

    var appearanceSection: some View {
        sectionLayout {
            Picker("Theme", selection: $themeManager.selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.radioGroup)
            .frame(width: 240)
            .padding(.top, -10)
            .padding(.leading, -60)
        } title: {
            Label("Appearance", systemImage: "paintpalette")
        }
    }

    var notificationsSection: some View {
        sectionLayout {
            Toggle(isOn: Binding(get: {
                notificationsEnabled
            }, set: { newValue in
                if newValue {
                    requestNotificationPermission()
                } else {
                    notificationsEnabled = false
                }
            })) {
                Text("Enable Notifications")
            }
            .padding(.top, -10)
            .padding(.leading, -90)
            .frame(width: 240)

            if notificationsEnabled {
                Text("Notifications are enabled ✅")
                    .foregroundColor(.green)
                    .font(.caption)
                    .padding(.top, -10)
                    .padding(.leading, 10)
            } else {
                Text("Notifications are disabled or permission not granted.")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            #if DEBUG
            Button("Send Test Notification") {
                sendTestNotification()
            }
            .buttonStyle(.bordered)
            #endif
        } title: {
            Label("Notifications", systemImage: "bell.fill")
        }
    }

    var advancedSection: some View {
        sectionLayout {
            Toggle("Offline Mode", isOn: $offlineMode)
                .padding(.top, -10)
                .padding(.leading, -120)
                .frame(width: 240)

            Button("Clear Cache") {
                amiiboService.clearCacheAndRefetch()
                showCacheClearedAlert = true
            }
            .buttonStyle(.bordered)

            Button("Reset App Data") {
                showResetAlert = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        } title: {
            Label("Advanced", systemImage: "gearshape")
        }
    }

    // MARK: - Helpers

    func sectionLayout<Content: View, Title: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder title: () -> Title
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            title()
                .font(.title2.bold())
                .padding(.bottom, 6)
                .padding(.top, 20)
            content()
        }
        .padding(.leading, 8)
        // ** Key: full width & height with topLeading alignment **
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func settingsButton(_ title: String, systemImage: String, foreground: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 240, height: 30, alignment: .leading)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
        .foregroundColor(foreground)
        .buttonStyle(PlainButtonStyle())
    }

    func iconName(for section: String) -> String {
        switch section {
        case "Account": return "person.crop.circle"
        case "Appearance": return "paintpalette"
        case "Notifications": return "bell.fill"
        case "Advanced": return "gearshape"
        default: return "gear"
        }
    }

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

#endif

