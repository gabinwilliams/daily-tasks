import SwiftUI
import Charts

struct TaskStatisticsView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                timeRangePicker
                
                if let stats = viewModel.taskStats {
                    statsCards(stats)
                    taskTrendChart(stats)
                    taskDistributionChart(stats)
                    detailedStats(stats)
                } else {
                    ProgressView()
                }
            }
            .padding()
        }
        .navigationTitle("Statistics")
        .task {
            await viewModel.updateTimeRange(viewModel.selectedTimeRange)
        }
    }
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedTimeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.description)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedTimeRange) { newValue in
            Task {
                await viewModel.updateTimeRange(newValue)
            }
        }
    }
    
    private func statsCards(_ stats: TaskStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Completion Rate",
                value: stats.completionRate,
                format: .percent,
                trend: 0.05,
                color: .blue
            )
            
            StatCard(
                title: "Approval Rate",
                value: stats.approvalRate,
                format: .percent,
                trend: -0.02,
                color: .green
            )
            
            StatCard(
                title: "Daily Average",
                value: stats.averageDailyTasks,
                format: .number,
                trend: 1.5,
                color: .orange
            )
            
            StatCard(
                title: "Total Tasks",
                value: Double(stats.totalTasks),
                format: .number,
                trend: 5,
                color: .purple
            )
        }
    }
    
    private func taskTrendChart(_ stats: TaskStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Completion Trend")
                .font(.headline)
            
            Chart {
                ForEach(stats.dailyStats) { stat in
                    LineMark(
                        x: .value("Date", stat.date),
                        y: .value("Tasks", stat.completedTasks)
                    )
                    .foregroundStyle(.blue)
                    
                    AreaMark(
                        x: .value("Date", stat.date),
                        y: .value("Tasks", stat.completedTasks)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func taskDistributionChart(_ stats: TaskStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Distribution")
                .font(.headline)
            
            Chart {
                SectorMark(
                    angle: .value("Tasks", stats.pendingTasks),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(.orange)
                
                SectorMark(
                    angle: .value("Tasks", stats.completedTasks),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(.blue)
                
                SectorMark(
                    angle: .value("Tasks", stats.approvedTasks),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(.green)
                
                SectorMark(
                    angle: .value("Tasks", stats.rejectedTasks),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(.red)
            }
            .frame(height: 200)
            
            VStack(spacing: 8) {
                LegendItem(color: .orange, label: "Pending (\(stats.pendingTasks))")
                LegendItem(color: .blue, label: "Completed (\(stats.completedTasks))")
                LegendItem(color: .green, label: "Approved (\(stats.approvedTasks))")
                LegendItem(color: .red, label: "Rejected (\(stats.rejectedTasks))")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func detailedStats(_ stats: TaskStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed Statistics")
                .font(.headline)
            
            VStack(spacing: 12) {
                StatRow("Total Tasks", "\(stats.totalTasks)")
                StatRow("Completed Tasks", "\(stats.completedTasks)")
                StatRow("Approval Rate", String(format: "%.1f%%", stats.approvalRate * 100))
                StatRow("Daily Average", String(format: "%.1f", stats.averageDailyTasks))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct StatCard: View {
    let title: String
    let value: Double
    let format: StatFormat
    let trend: Double
    let color: Color
    
    enum StatFormat {
        case percent
        case number
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formattedValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            HStack {
                Image(systemName: trendIcon)
                    .foregroundColor(trendColor)
                
                Text(formattedTrend)
                    .font(.caption)
                    .foregroundColor(trendColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var formattedValue: String {
        switch format {
        case .percent:
            return String(format: "%.1f%%", value * 100)
        case .number:
            return String(format: "%.1f", value)
        }
    }
    
    private var formattedTrend: String {
        String(format: "%+.1f%%", trend * 100)
    }
    
    private var trendIcon: String {
        trend > 0 ? "arrow.up.right" : "arrow.down.right"
    }
    
    private var trendColor: Color {
        trend > 0 ? .green : .red
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Supporting Types

enum TimeRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

enum StatFormat {
    case percent
    case number
}

struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let totalTasks: Int
    let completedTasks: Int
    let approvedTasks: Int
}

struct TaskStats {
    let totalTasks: Int
    let completedTasks: Int
    let approvedTasks: Int
    let rejectedTasks: Int
    let pendingTasks: Int
    let completionRate: Double
    let approvalRate: Double
    let completionTrend: Double
    let approvalTrend: Double
    let averageResponseTime: TimeInterval
    let dailyStats: [DailyStats]
}

// MARK: - Preview

struct TaskStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TaskStatisticsView(viewModel: TaskListViewModel(userRole: .parent))
        }
    }
} 