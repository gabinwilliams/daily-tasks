import SwiftUI

struct TaskReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var settings: ReminderSettings
    @State private var isLoading = false
    @State private var showingAuthAlert = false
    
    let task: Task
    let onUpdate: (ReminderSettings) -> Void
    
    init(task: Task, onUpdate: @escaping (ReminderSettings) -> Void) {
        self.task = task
        self.onUpdate = onUpdate
        _settings = State(initialValue: task.reminderSettings ?? .default)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Upcoming Reminder", isOn: $settings.enableUpcoming)
                    
                    if settings.enableUpcoming {
                        Stepper(
                            "\(settings.upcomingMinutesBefore) minutes before",
                            value: $settings.upcomingMinutesBefore,
                            in: 5...1440,
                            step: 5
                        )
                    }
                } header: {
                    Text("Upcoming Reminder")
                } footer: {
                    Text("Receive a reminder before the task is due")
                }
                
                Section {
                    Toggle("Enable Due Today Reminder", isOn: $settings.enableDueToday)
                    
                    if settings.enableDueToday {
                        DatePicker(
                            "Reminder Time",
                            selection: $settings.dueTodayTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Due Today Reminder")
                } footer: {
                    Text("Receive a reminder on the day the task is due")
                }
                
                Section {
                    Toggle("Enable Overdue Reminder", isOn: $settings.enableOverdue)
                } header: {
                    Text("Overdue Reminder")
                } footer: {
                    Text("Receive a reminder when the task becomes overdue")
                }
            }
            .navigationTitle("Reminder Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(isLoading)
                }
            }
            .onChange(of: notificationManager.isAuthorized) { authorized in
                if !authorized && (settings.enableUpcoming || settings.enableDueToday || settings.enableOverdue) {
                    showingAuthAlert = true
                }
            }
            .alert("Enable Notifications", isPresented: $showingAuthAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    settings.enableUpcoming = false
                    settings.enableDueToday = false
                    settings.enableOverdue = false
                }
            } message: {
                Text("Notifications are required for reminders. Would you like to enable them in Settings?")
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func saveSettings() {
        isLoading = true
        
        Task {
            do {
                // Cancel existing reminders
                await notificationManager.cancelTaskReminders(for: task.id)
                
                // Schedule new reminders if authorized
                if notificationManager.isAuthorized {
                    // Upcoming reminder
                    if settings.enableUpcoming {
                        let reminderDate = task.dueDate.addingTimeInterval(-Double(settings.upcomingMinutesBefore * 60))
                        if reminderDate > Date() {
                            try await notificationManager.scheduleTaskReminder(
                                for: task,
                                at: reminderDate,
                                type: .upcoming
                            )
                        }
                    }
                    
                    // Due today reminder
                    if settings.enableDueToday {
                        let calendar = Calendar.current
                        let dueComponents = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: settings.dueTodayTime)
                        var reminderComponents = DateComponents()
                        reminderComponents.year = dueComponents.year
                        reminderComponents.month = dueComponents.month
                        reminderComponents.day = dueComponents.day
                        reminderComponents.hour = timeComponents.hour
                        reminderComponents.minute = timeComponents.minute
                        
                        if let reminderDate = calendar.date(from: reminderComponents), reminderDate > Date() {
                            try await notificationManager.scheduleTaskReminder(
                                for: task,
                                at: reminderDate,
                                type: .dueToday
                            )
                        }
                    }
                    
                    // Overdue reminder
                    if settings.enableOverdue {
                        try await notificationManager.scheduleTaskReminder(
                            for: task,
                            at: task.dueDate,
                            type: .overdue
                        )
                    }
                } else if settings.enableUpcoming || settings.enableDueToday || settings.enableOverdue {
                    showingAuthAlert = true
                    isLoading = false
                    return
                }
                
                // Update task with new settings
                onUpdate(settings)
                dismiss()
            } catch {
                print("Error scheduling reminders: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
}

struct TaskReminderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TaskReminderSettingsView(
            task: Task(
                id: "1",
                kidId: "kid1",
                title: "Clean Room",
                description: "Make your bed and organize your desk",
                status: .pending,
                photoUrl: nil,
                parentComment: nil,
                dueDate: Date().addingTimeInterval(3600),
                createdAt: Date(),
                updatedAt: Date(),
                reminderSettings: .default
            )
        ) { _ in }
    }
} 