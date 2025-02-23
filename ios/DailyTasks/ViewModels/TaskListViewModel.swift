import Foundation
import Combine
import SwiftUI

@MainActor
class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var filterStatus: TaskStatus?
    @Published var hasMoreTasks = true
    @Published var taskStats: TaskStats?
    @Published var selectedTimeRange: TimeRange = .week
    @Published var isLoadingStats = false
    
    let userRole: UserRole
    private let taskManager: TaskManager
    private let notificationManager = NotificationManager.shared
    private var nextToken: String?
    private var isFetchingMore = false
    private let apiClient = APIClient.shared
    
    init(userRole: UserRole, taskManager: TaskManager = .shared) {
        self.userRole = userRole
        self.taskManager = taskManager
        fetchTasks()
    }
    
    func fetchTasks() async {
        isLoading = true
        error = nil
        
        do {
            tasks = try await taskManager.fetchTasks()
            isLoading = false
        } catch {
            self.error = error
            tasks = []
            isLoading = false
        }
    }
    
    func loadMoreTasksIfNeeded(currentTask task: Task) {
        guard !isFetchingMore,
              hasMoreTasks,
              let index = tasks.firstIndex(where: { $0.id == task.id }),
              index == tasks.count - 5 else {
            return
        }
        
        isFetchingMore = true
        fetchTasks()
        isFetchingMore = false
    }
    
    func setFilter(_ status: TaskStatus?) {
        filterStatus = status
        fetchTasks()
    }
    
    func createTask(title: String, description: String, dueDate: Date, kidId: String) async throws -> Task {
        isLoading = true
        error = nil
        
        do {
            let task = try await taskManager.createTask(
                title: title,
                description: description,
                dueDate: dueDate,
                kidId: kidId
            )
            tasks.append(task)
            isLoading = false
            return task
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func deleteTask(_ task: Task) async throws {
        isLoading = true
        error = nil
        
        do {
            // Cancel any existing notifications before deleting
            await notificationManager.cancelTaskReminders(for: task.id)
            
            try await taskManager.deleteTask(task)
            tasks.removeAll { $0.id == task.id }
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    func updateTaskStatus(_ task: Task, newStatus: TaskStatus) async throws {
        isLoading = true
        error = nil
        
        do {
            let updatedTask = try await taskManager.updateTaskStatus(task, newStatus: newStatus)
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = updatedTask
            }
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    private func scheduleTaskReminders(for task: Task) async throws {
        guard let settings = task.reminderSettings ?? ReminderSettings.default else { return }
        
        // Schedule upcoming reminder
        if settings.enableUpcoming && task.dueDate > Date() {
            let reminderDate = Calendar.current.date(
                byAdding: .minute,
                value: -settings.upcomingMinutesBefore,
                to: task.dueDate
            )
            if let date = reminderDate, date > Date() {
                try await notificationManager.scheduleTaskReminder(
                    for: task,
                    at: date,
                    type: .upcoming
                )
            }
        }
        
        // Schedule due today reminder
        if settings.enableDueToday {
            let calendar = Calendar.current
            let dueDate = calendar.startOfDay(for: task.dueDate)
            let now = calendar.startOfDay(for: Date())
            
            if dueDate == now {
                try await notificationManager.scheduleTaskReminder(
                    for: task,
                    at: settings.dueTodayTime,
                    type: .dueToday
                )
            }
        }
        
        // Schedule overdue reminder
        if settings.enableOverdue {
            try await notificationManager.scheduleTaskReminder(
                for: task,
                at: task.dueDate,
                type: .overdue
            )
        }
    }
    
    func calculateStats(for range: TimeRange) -> TaskStats {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -range.days, to: now) ?? now
        
        let filteredTasks = tasks.filter { $0.createdAt >= startDate }
        let completedTasks = filteredTasks.filter { $0.status == .completed || $0.status == .approved }
        let approvedTasks = filteredTasks.filter { $0.status == .approved }
        let rejectedTasks = filteredTasks.filter { $0.status == .rejected }
        let pendingTasks = filteredTasks.filter { $0.status == .pending }
        
        // Calculate daily stats
        var dailyStats: [DailyStats] = []
        var currentDate = startDate
        
        while currentDate <= now {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let dayTasks = filteredTasks.filter { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
            let dayCompleted = dayTasks.filter { $0.status == .completed || $0.status == .approved }
            let dayApproved = dayTasks.filter { $0.status == .approved }
            
            dailyStats.append(DailyStats(
                date: currentDate,
                totalTasks: dayTasks.count,
                completedTasks: dayCompleted.count,
                approvedTasks: dayApproved.count
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Calculate trends
        let previousPeriodStart = calendar.date(byAdding: .day, value: -(range.days * 2), to: now)!
        let previousPeriodTasks = tasks.filter { $0.createdAt >= previousPeriodStart && $0.createdAt < startDate }
        
        let previousCompletionRate = previousPeriodTasks.isEmpty ? 0 :
            Double(previousPeriodTasks.filter { $0.status == .completed || $0.status == .approved }.count) /
            Double(previousPeriodTasks.count)
        
        let previousApprovalRate = previousPeriodTasks.isEmpty ? 0 :
            Double(previousPeriodTasks.filter { $0.status == .approved }.count) /
            Double(previousPeriodTasks.count)
        
        let currentCompletionRate = filteredTasks.isEmpty ? 0 :
            Double(completedTasks.count) / Double(filteredTasks.count)
        
        let currentApprovalRate = filteredTasks.isEmpty ? 0 :
            Double(approvedTasks.count) / Double(filteredTasks.count)
        
        let completionTrend = previousCompletionRate == 0 ? 0 :
            ((currentCompletionRate - previousCompletionRate) / previousCompletionRate) * 100
        
        let approvalTrend = previousApprovalRate == 0 ? 0 :
            ((currentApprovalRate - previousApprovalRate) / previousApprovalRate) * 100
        
        // Calculate average response time
        let responseTimes = completedTasks.compactMap { task in
            task.updatedAt.timeIntervalSince(task.createdAt)
        }
        
        let averageResponseTime = responseTimes.isEmpty ? 0 :
            responseTimes.reduce(0, +) / Double(responseTimes.count)
        
        return TaskStats(
            totalTasks: filteredTasks.count,
            completedTasks: completedTasks.count,
            approvedTasks: approvedTasks.count,
            rejectedTasks: rejectedTasks.count,
            pendingTasks: pendingTasks.count,
            completionRate: currentCompletionRate,
            approvalRate: currentApprovalRate,
            completionTrend: completionTrend,
            approvalTrend: approvalTrend,
            averageResponseTime: averageResponseTime,
            dailyStats: dailyStats
        )
    }
    
    func approveTask(_ task: Task) async throws {
        try await updateTaskStatus(task, newStatus: .approved)
    }
    
    func rejectTask(_ task: Task) async throws {
        try await updateTaskStatus(task, newStatus: .rejected)
    }
    
    func resetTask(_ task: Task) async throws {
        try await updateTaskStatus(task, newStatus: .pending)
    }
    
    @MainActor
    func fetchTaskStats(for kidId: String? = nil) async {
        isLoadingStats = true
        error = nil
        
        do {
            taskStats = try await apiClient.getTaskStats(timeRange: selectedTimeRange, kidId: kidId)
        } catch {
            self.error = error
        }
        
        isLoadingStats = false
    }
    
    @MainActor
    func updateTimeRange(_ timeRange: TimeRange) async {
        selectedTimeRange = timeRange
        await fetchTaskStats()
    }
}

// MARK: - Task Filtering

extension TaskListViewModel {
    var filteredTasks: [Task] {
        guard let filterStatus = filterStatus else {
            return tasks
        }
        
        return tasks.filter { $0.status == filterStatus }
    }
    
    var pendingTasks: [Task] {
        tasks.filter { $0.status == .pending }
    }
    
    var completedTasks: [Task] {
        tasks.filter { $0.status == .completed }
    }
    
    var approvedTasks: [Task] {
        tasks.filter { $0.status == .approved }
    }
    
    var rejectedTasks: [Task] {
        tasks.filter { $0.status == .rejected }
    }
}

// MARK: - Task Statistics

extension TaskListViewModel {
    var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.status == .completed || $0.status == .approved }
        return Double(completed.count) / Double(tasks.count)
    }
    
    var approvalRate: Double {
        guard !tasks.isEmpty else { return 0 }
        let approved = tasks.filter { $0.status == .approved }
        return Double(approved.count) / Double(tasks.count)
    }
    
    var averageCompletionTime: TimeInterval {
        let completedTasks = tasks.filter { $0.status == .completed || $0.status == .approved }
        guard !completedTasks.isEmpty else { return 0 }
        
        let totalTime = completedTasks.reduce(0) { total, task in
            guard let completionTime = task.updatedAt.timeIntervalSince(task.createdAt) else {
                return total
            }
            return total + completionTime
        }
        
        return totalTime / Double(completedTasks.count)
    }
} 