import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("dailyReminder") private var dailyReminder = true
    @AppStorage("reminderTime") private var reminderTime = Date()
    
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    if let user = authManager.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading) {
                                Text(user.email)
                                    .font(.headline)
                                Text(user.role.rawValue.capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Toggle("Daily Reminder", isOn: $dailyReminder)
                        
                        if dailyReminder {
                            DatePicker(
                                "Reminder Time",
                                selection: $reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }
                
                // Account Section
                Section("Account") {
                    Button {
                        showingChangePassword = true
                    } label: {
                        Label("Change Password", systemImage: "lock")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAccount = true
                    } label: {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                    }
                }
                
                // App Info Section
                Section("App Info") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
            .alert("Delete Account", isPresented: $showingDeleteAccount) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .onChange(of: notificationsEnabled) { enabled in
                updateNotificationSettings(enabled: enabled)
            }
            .onChange(of: dailyReminder) { enabled in
                updateReminderSettings(enabled: enabled)
            }
            .onChange(of: reminderTime) { time in
                updateReminderTime(time)
            }
        }
    }
    
    private func updateNotificationSettings(enabled: Bool) {
        if enabled {
            requestNotificationPermission()
        } else {
            // Disable all notifications
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    private func updateReminderSettings(enabled: Bool) {
        if enabled {
            scheduleReminder()
        } else {
            // Remove daily reminder
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        }
    }
    
    private func updateReminderTime(_ time: Date) {
        if dailyReminder {
            scheduleReminder()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                notificationsEnabled = granted
            }
        }
    }
    
    private func scheduleReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Tasks Reminder"
        content.body = "Don't forget to check your tasks for today!"
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "dailyReminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling reminder: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await authManager.deleteAccount()
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthenticationManager.shared)
    }
} 