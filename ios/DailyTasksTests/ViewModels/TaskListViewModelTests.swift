import XCTest
@testable import DailyTasks

final class TaskListViewModelTests: XCTestCase {
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
    
    // MARK: - Task Fetching Tests
    
    func testFetchTasksSuccess() async {
        // Given
        let mockTasks = [
            Task(id: "1", kidId: "kid1", title: "Test Task 1", description: "Description 1", status: .pending, dueDate: Date(), createdAt: Date(), updatedAt: Date()),
            Task(id: "2", kidId: "kid1", title: "Test Task 2", description: "Description 2", status: .completed, dueDate: Date(), createdAt: Date(), updatedAt: Date())
        ]
        mockTaskManager.mockTasks = mockTasks
        
        // When
        await viewModel.fetchTasks()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.tasks.count, 2)
        XCTAssertEqual(viewModel.tasks[0].id, "1")
        XCTAssertEqual(viewModel.tasks[1].id, "2")
    }
    
    func testFetchTasksFailure() async {
        // Given
        let expectedError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        mockTaskManager.mockError = expectedError
        
        // When
        await viewModel.fetchTasks()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.error)
        XCTAssertEqual(viewModel.tasks.count, 0)
    }
}

// MARK: - Mock Task Manager

class MockTaskManager {
    var mockTasks: [Task] = []
    var mockError: Error?
    
    func fetchTasks() async throws -> [Task] {
        if let error = mockError {
            throw error
        }
        return mockTasks
    }
} 