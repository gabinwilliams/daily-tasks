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
    
    // MARK: - Task Filtering Tests
    
    func testFilterTasks() {
        // Given
        let pendingTask = createMockTask(status: .pending)
        let completedTask = createMockTask(status: .completed)
        viewModel.tasks = [pendingTask, completedTask]
        
        // When
        viewModel.setFilter(.completed)
        
        // Then
        XCTAssertEqual(viewModel.filteredTasks.count, 1)
        XCTAssertEqual(viewModel.filteredTasks.first?.status, .completed)
    }
    
    func testClearFilter() {
        // Given
        let tasks = [createMockTask(status: .pending), createMockTask(status: .completed)]
        viewModel.tasks = tasks
        viewModel.setFilter(.completed)
        
        // When
        viewModel.setFilter(nil)
        
        // Then
        XCTAssertEqual(viewModel.filteredTasks.count, tasks.count)
    }
    
    // MARK: - Task Creation Tests
    
    func testCreateTaskSuccess() async {
        // Given
        let title = "New Task"
        let description = "Task Description"
        let dueDate = Date()
        let kidId = "kid1"
        
        let expectedTask = Task(id: "new", kidId: kidId, title: title, description: description, status: .pending, dueDate: dueDate, createdAt: Date(), updatedAt: Date())
        mockTaskManager.mockCreatedTask = expectedTask
        
        // When
        do {
            let createdTask = try await viewModel.createTask(title: title, description: description, dueDate: dueDate, kidId: kidId)
            
            // Then
            XCTAssertEqual(createdTask.id, expectedTask.id)
            XCTAssertEqual(createdTask.title, title)
            XCTAssertEqual(createdTask.description, description)
            XCTAssertEqual(createdTask.kidId, kidId)
            XCTAssertEqual(createdTask.status, .pending)
        } catch {
            XCTFail("Task creation should not fail: \(error)")
        }
    }
    
    func testCreateTaskFailure() async {
        // Given
        let expectedError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Creation failed"])
        mockTaskManager.mockError = expectedError
        
        // When
        do {
            _ = try await viewModel.createTask(title: "Test", description: "Test", dueDate: Date(), kidId: "kid1")
            XCTFail("Task creation should fail")
        } catch {
            // Then
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Task Update Tests
    
    func testUpdateTaskStatusSuccess() async {
        // Given
        let task = Task(id: "1", kidId: "kid1", title: "Test Task", description: "Description", status: .pending, dueDate: Date(), createdAt: Date(), updatedAt: Date())
        mockTaskManager.mockTasks = [task]
        
        // When
        do {
            try await viewModel.updateTaskStatus(task, newStatus: .completed)
            
            // Then
            XCTAssertEqual(mockTaskManager.lastUpdatedTask?.status, .completed)
        } catch {
            XCTFail("Task update should not fail: \(error)")
        }
    }
    
    func testUpdateTaskStatusFailure() async {
        // Given
        let task = Task(id: "1", kidId: "kid1", title: "Test Task", description: "Description", status: .pending, dueDate: Date(), createdAt: Date(), updatedAt: Date())
        let expectedError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update failed"])
        mockTaskManager.mockError = expectedError
        
        // When
        do {
            try await viewModel.updateTaskStatus(task, newStatus: .completed)
            XCTFail("Task update should fail")
        } catch {
            // Then
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Task Statistics Tests
    
    func testFetchTaskStatsSuccess() async {
        // Given
        let mockStats = TaskStats(
            timeRange: .week,
            totalTasks: 10,
            completedTasks: 5,
            approvedTasks: 3,
            rejectedTasks: 2,
            pendingTasks: 5,
            dailyStats: [],
            kidId: nil
        )
        mockTaskManager.mockTaskStats = mockStats
        
        // When
        await viewModel.fetchTaskStats()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertNotNil(viewModel.taskStats)
        XCTAssertEqual(viewModel.taskStats?.totalTasks, 10)
        XCTAssertEqual(viewModel.taskStats?.completedTasks, 5)
    }
    
    func testFetchTaskStatsFailure() async {
        // Given
        mockTaskManager.mockError = NSError(domain: "test", code: -1)
        
        // When
        await viewModel.fetchTaskStats()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.error)
        XCTAssertNil(viewModel.taskStats)
    }
    
    // MARK: - Helper Methods
    
    private func createMockTask(id: String, status: TaskStatus = .pending) -> Task {
        Task(
            id: id,
            kidId: "kid1",
            title: "Test Task",
            description: "Test Description",
            status: status,
            photoUrl: nil,
            parentComment: nil,
            dueDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Mock Task Manager

class MockTaskManager {
    var mockTasks: [Task] = []
    var mockCreatedTask: Task?
    var mockUpdatedTask: Task?
    var mockTaskStats: TaskStats?
    var mockError: Error?
    var lastUpdatedTask: Task?
    
    func fetchTasks() async throws -> [Task] {
        if let error = mockError {
            throw error
        }
        return mockTasks
    }
    
    func createTask(title: String, description: String, dueDate: Date, kidId: String) async throws -> Task {
        if let error = mockError {
            throw error
        }
        return mockCreatedTask ?? Task(id: "mock", kidId: kidId, title: title, description: description, status: .pending, dueDate: dueDate, createdAt: Date(), updatedAt: Date())
    }
    
    func updateTaskStatus(_ task: Task, newStatus: TaskStatus) async throws {
        if let error = mockError {
            throw error
        }
        lastUpdatedTask = task
        lastUpdatedTask?.status = newStatus
    }
    
    func getTaskStats(timeRange: TimeRange = .week, kidId: String? = nil) async throws -> TaskStats {
        if let error = mockError {
            throw error
        }
        return mockTaskStats ?? TaskStats(
            timeRange: .week,
            totalTasks: 0,
            completedTasks: 0,
            approvedTasks: 0,
            rejectedTasks: 0,
            pendingTasks: 0,
            dailyStats: [],
            kidId: nil
        )
    }
    
    private func createMockTask(id: String) -> Task {
        Task(
            id: id,
            kidId: "kid1",
            title: "Test Task",
            description: "Test Description",
            status: .pending,
            photoUrl: nil,
            parentComment: nil,
            dueDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}