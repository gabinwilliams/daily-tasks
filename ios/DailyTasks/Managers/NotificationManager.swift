import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published private(set) var isAuthorized = false
    @Published private(set) var error: Error?
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        Task {
            await checkAuthorizationStatus()
            await refreshPendingNotifications()
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    func requestAuthorization() async throws {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
                error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error
                isAuthorized = false
            }
            throw error
        }
    }
    
    func scheduleTaskReminder(for task: Task, at date: Date, type: TaskReminderType) async throws {
        guard isAuthorized else {
            throw NotificationError.notAuthorized
        }
        
        let content = UNMutableNotificationContent()
        content.title = type.title(for: task)
        content.body = type.body(for: task)
        content.sound = .default
        content.userInfo = ["taskId": task.id]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = notificationIdentifier(for: task.id, type: type)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            await MainActor.run {
                error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func cancelTaskReminders(for taskId: String) async {
        let identifiers = TaskReminderType.allCases.map { notificationIdentifier(for: taskId, type: $0) }
        await center.removePendingNotificationRequests(withIdentifiers: identifiers)
        await center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func refreshPendingNotifications() async {
        pendingNotifications = await center.pendingNotificationRequests()
    }
    
    private func notificationIdentifier(for taskId: String, type: TaskReminderType) -> String {
        "task-\(taskId)-\(type.rawValue)"
    }
}

// MARK: - Supporting Types

enum TaskReminderType: String, CaseIterable {
    case upcoming
    case dueToday
    case overdue
    case statusChange
    
    func title(for task: Task) -> String {
        switch self {
        case .upcoming:
            return "Upcoming Task"
        case .dueToday:
            return "Task Due Today"
        case .overdue:
            return "Task Overdue"
        case .statusChange:
            return "Task Status Updated"
        }
    }
    
    func body(for task: Task) -> String {
        switch self {
        case .upcoming:
            return "Task '\(task.title)' is coming up soon."
        case .dueToday:
            return "Task '\(task.title)' is due today."
        case .overdue:
            return "Task '\(task.title)' is now overdue."
        case .statusChange:
            return "Task '\(task.title)' status has been updated to \(task.status.rawValue)."
        }
    }
}

enum NotificationError: LocalizedError {
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notifications are not authorized. Please enable them in Settings."
        }
    }
} 