import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var reminderTime = Date()
    @State private var isReminderEnabled = false
    
    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                Toggle("Enable Daily Reminders", isOn: $isReminderEnabled)
                    .onChange(of: isReminderEnabled) { newValue in
                        if newValue {
                            viewModel.scheduleReminder(at: reminderTime)
                        } else {
                            viewModel.cancelReminder()
                        }
                        UserDefaults.standard.set(newValue, forKey: "isReminderEnabled")
                    }
                
                if isReminderEnabled {
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTime) { newValue in
                            viewModel.scheduleReminder(at: newValue)
                            UserDefaults.standard.set(newValue, forKey: "reminderTime")
                        }
                }
            }
            
            Section(header: Text("Account")) {
                Button("Sign Out") {
                    viewModel.signOut()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            isReminderEnabled = UserDefaults.standard.bool(forKey: "isReminderEnabled")
            if let savedTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date {
                reminderTime = savedTime
            }
        }
    }
} 