import Foundation

public enum TimeRange: String, Codable, CaseIterable, Identifiable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .week:
            return "Last 7 Days"
        case .month:
            return "Last 30 Days"
        case .year:
            return "Last 365 Days"
        }
    }
    
    public var days: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 365
        }
    }
}

public struct DailyStats: Codable, Identifiable {
    public let date: Date
    public let totalTasks: Int
    public let completedTasks: Int
    public let approvedTasks: Int
    public let rejectedTasks: Int
    
    public var id: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    
    public var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    public var approvalRate: Double {
        guard completedTasks > 0 else { return 0 }
        return Double(approvedTasks) / Double(completedTasks)
    }
}

public struct TaskStats: Codable {
    public let timeRange: TimeRange
    public let totalTasks: Int
    public let completedTasks: Int
    public let approvedTasks: Int
    public let rejectedTasks: Int
    public let pendingTasks: Int
    public let completionRate: Double
    public let approvalRate: Double
    public let completionTrend: Double
    public let approvalTrend: Double
    public let averageResponseTime: TimeInterval
    public let dailyStats: [DailyStats]
    
    public init(
        timeRange: TimeRange,
        totalTasks: Int,
        completedTasks: Int,
        approvedTasks: Int,
        rejectedTasks: Int,
        pendingTasks: Int,
        completionRate: Double,
        approvalRate: Double,
        completionTrend: Double,
        approvalTrend: Double,
        averageResponseTime: TimeInterval,
        dailyStats: [DailyStats]
    ) {
        self.timeRange = timeRange
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.approvedTasks = approvedTasks
        self.rejectedTasks = rejectedTasks
        self.pendingTasks = pendingTasks
        self.completionRate = completionRate
        self.approvalRate = approvalRate
        self.completionTrend = completionTrend
        self.approvalTrend = approvalTrend
        self.averageResponseTime = averageResponseTime
        self.dailyStats = dailyStats
    }
} 