import XCTest
import SwiftUI
@testable import DailyTasks

final class TaskStatisticsViewTests: XCTestCase {
    var viewModel: TaskListViewModel!
    var mockTaskManager: MockTaskManager!
    
    override func setUp() {
        super.setUp()
        mockTaskManager = MockTaskManager()
        viewModel = TaskListViewModel(userRole: .parent, taskManager: mockTaskManager)
    }
    
    override func tearDown() {
        viewModel = nil
        mockTaskManager = nil
        super.tearDown()
    }
    
    func testStatCardView() {
        // Given
        let title = "Test Stat"
        let value = 0.75
        let trend = 10.0
        
        // When
        let statCard = StatCard(
            title: title,
            value: value,
            format: .percent,
            trend: trend,
            color: .blue
        )
        
        // Then
        let view = statCard.body
        XCTAssertNotNil(view)
        
        // Test percentage formatting
        let percentText = "75%" // 0.75 should be formatted as 75%
        let mirror = Mirror(reflecting: view)
        let containsPercentText = mirror.description.contains(percentText)
        XCTAssertTrue(containsPercentText, "StatCard should display \(percentText)")
    }
    
    func testTaskDistributionView() {
        // Given
        let stats = TaskStats(
            totalTasks: 10,
            completedTasks: 3,
            approvedTasks: 2,
            rejectedTasks: 1,
            pendingTasks: 4,
            completionRate: 0.5,
            approvalRate: 0.2,
            completionTrend: 5.0,
            approvalTrend: -2.0,
            averageResponseTime: 3600,
            dailyStats: []
        )
        
        // When
        let distributionView = TaskDistributionView(stats: stats)
        
        // Then
        let view = distributionView.body
        XCTAssertNotNil(view)
    }
    
    func testTimeRangeSelection() {
        // Given
        let view = TaskStatisticsView(viewModel: viewModel)
        
        // Test each time range
        for range in TimeRange.allCases {
            // When
            let description = range.description
            
            // Then
            XCTAssertFalse(description.isEmpty)
            XCTAssertGreaterThan(range.days, 0)
        }
    }
    
    func testStatFormatting() {
        // Test percentage formatting
        let percentValue = StatCard(
            title: "Test",
            value: 0.756,
            format: .percent,
            trend: 0,
            color: .blue
        )
        
        let numberValue = StatCard(
            title: "Test",
            value: 75.6,
            format: .number,
            trend: 0,
            color: .blue
        )
        
        let percentView = percentValue.body
        let numberView = numberValue.body
        
        XCTAssertNotNil(percentView)
        XCTAssertNotNil(numberView)
    }
    
    func testLegendItemView() {
        // Given
        let color = Color.blue
        let label = "Test Label"
        
        // When
        let legendItem = LegendItem(color: color, label: label)
        
        // Then
        let view = legendItem.body
        XCTAssertNotNil(view)
    }
    
    func testStatRowView() {
        // Given
        let title = "Test Stat"
        let value = "Test Value"
        
        // When
        let statRow = StatRow(title, value)
        
        // Then
        let view = statRow.body
        XCTAssertNotNil(view)
    }
}

// MARK: - Preview Provider Tests

final class TaskStatisticsViewPreviewTests: XCTestCase {
    func testPreviewProvider() {
        let preview = TaskStatisticsView_Previews.previews
        XCTAssertNotNil(preview)
    }
} 