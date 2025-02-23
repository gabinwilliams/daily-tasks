import SwiftUI
import Charts

struct TaskStatisticsView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let stats = viewModel.taskStats {
                    timeRangePicker
                    statsCards(stats)
                    taskTrendChart(stats)
                    taskDistributionChart(stats)
                    detailedStats(stats)
                } else {
                    Text("No statistics available")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Task Statistics")
    }
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedTimeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.description).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private func statsCards(_ stats: TaskStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(title: "Total Tasks", value: "\(stats.totalTasks)")
            StatCard(title: "Completed Tasks", value: "\(stats.completedTasks)")
            StatCard(title: "Completion Rate", value: String(format: "%.1f%%", stats.completionRate * 100))
            StatCard(title: "Average Daily Tasks", value: String(format: "%.1f", stats.averageDailyTasks))
        }
    }
    
    private func taskTrendChart(_ stats: TaskStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Completion Trend")
                .font(.headline)
            
            Chart {
                ForEach(stats.dailyStats) { daily in
                    LineMark(
                        x: .value("Date", daily.date),
                        y: .value("Tasks", daily.completedTasks)
                    )
                    .foregroundStyle(.blue)
                    
                    AreaMark(
                        x: .value("Date", daily.date),
                        y: .value("Tasks", daily.completedTasks)
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
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func taskDistributionChart(_ stats: TaskStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Distribution")
                .font(.headline)
            
            Chart {
                ForEach(stats.tasksByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                    SectorMark(
                        angle: .value("Tasks", count),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", category))
                }
            }
            .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(stats.tasksByCategory.sorted(by: { $0.value > $1.value })), id: \.key) { category, count in
                    LegendItem(category: category, count: count, total: stats.totalTasks)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func detailedStats(_ stats: TaskStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed Statistics")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                StatRow(title: "Most Productive Day", value: stats.mostProductiveDay?.formatted(date: .complete, time: .omitted) ?? "N/A")
                StatRow(title: "Least Productive Day", value: stats.leastProductiveDay?.formatted(date: .complete, time: .omitted) ?? "N/A")
                StatRow(title: "Average Completion Time", value: formatDuration(stats.averageCompletionTime))
                StatRow(title: "Streak", value: "\(stats.currentStreak) days")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
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

struct LegendItem: View {
    let category: String
    let count: Int
    let total: Int
    
    var percentage: Double {
        Double(count) / Double(total) * 100
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue) // You might want to use different colors based on category
                .frame(width: 8, height: 8)
            Text(category)
                .font(.caption)
            Spacer()
            Text("\(count) (\(String(format: "%.1f%%", percentage))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
} 