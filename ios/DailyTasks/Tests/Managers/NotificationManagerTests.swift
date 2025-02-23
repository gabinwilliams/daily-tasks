import XCTest
import UserNotifications
@testable import DailyTasks

final class NotificationManagerTests: XCTestCase {
    var notificationManager: NotificationManager!
    var mockNotificationCenter: MockUserNotificationCenter!
    
    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockUserNotificationCenter()
        notificationManager = NotificationManager.shared
        // Inject mock notification center
        notificationManager.notificationCenter = mockNotificationCenter
    }
    
    override func tearDown() {
        notificationManager = nil
        mockNotificationCenter = nil
        super.tearDown()
    }
    
    func testRequestAuthorization() async throws {
        // Given
        mockNotificationCenter.authorizationStatus = .notDetermined
        mockNotificationCenter.shouldGrantAuthorization = true
        
        // When
        try await notificationManager.requestAuthorization()
        
        // Then
        XCTAssertTrue(notificationManager.isAuthorized)
        XCTAssertTrue(mockNotificationCenter.didRequestAuthorization)
    }
    
    func testRequestAuthorizationDenied() async {
        // Given
        mockNotificationCenter.authorizationStatus = .denied
        mockNotificationCenter.shouldGrantAuthorization = false
        
        // When/Then
        do {
            try await notificationManager.requestAuthorization()
            XCTFail("Should throw error when authorization is denied")
        } catch {
            XCTAssertFalse(notificationManager.isAuthorized)
        }
    }
    
    func testScheduleTaskReminder() async throws {
        // Given
        mockNotificationCenter.authorizationStatus = .authorized
        let task = createMockTask()
        let date = Date().addingTimeInterval(3600) // 1 hour from now
        
        // When
        try await notificationManager.scheduleTaskReminder(
            for: task,
            at: date,
            type: .upcoming
        )
        
        // Then
        XCTAssertEqual(mockNotificationCenter.addedRequests.count, 1)
        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first)
        XCTAssertEqual(request.content.title, ReminderType.upcoming.title)
        XCTAssertTrue(request.identifier.contains(task.id))
    }
    
    func testScheduleTaskReminderUnauthorized() async {
        // Given
        mockNotificationCenter.authorizationStatus = .denied
        let task = createMockTask()
        let date = Date().addingTimeInterval(3600)
        
        // When/Then
        do {
            try await notificationManager.scheduleTaskReminder(
                for: task,
                at: date,
                type: .upcoming
            )
            XCTFail("Should throw error when notifications are not authorized")
        } catch {
            XCTAssertEqual(error as? NotificationError, .notAuthorized)
        }
    }
    
    func testCancelTaskReminders() async {
        // Given
        let taskId = "test-task-id"
        
        // When
        await notificationManager.cancelTaskReminders(for: taskId)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.didRemoveRequests)
        let identifiers = mockNotificationCenter.removedIdentifiers
        XCTAssertFalse(identifiers.isEmpty)
        XCTAssertTrue(identifiers.allSatisfy { $0.contains(taskId) })
    }
    
    func testRefreshPendingNotifications() async {
        // Given
        let requests = [
            createMockNotificationRequest(identifier: "test-1"),
            createMockNotificationRequest(identifier: "test-2")
        ]
        mockNotificationCenter.pendingRequests = requests
        
        // When
        await notificationManager.refreshPendingNotifications()
        
        // Then
        XCTAssertEqual(notificationManager.pendingNotifications.count, requests.count)
    }
    
    // MARK: - Helper Methods
    
    private func createMockTask() -> Task {
        Task(
            id: "test-task-id",
            kidId: "kid1",
            title: "Test Task",
            description: "Test Description",
            status: .pending,
            photoUrl: nil,
            parentComment: nil,
            dueDate: Date().addingTimeInterval(3600),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createMockNotificationRequest(identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}

// MARK: - Mock UNUserNotificationCenter

class MockUserNotificationCenter: UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var shouldGrantAuthorization = true
    var didRequestAuthorization = false
    var didRemoveRequests = false
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var pendingRequests: [UNNotificationRequest] = []
    
    override func requestAuthorization(
        options: UNAuthorizationOptions
    ) async throws -> Bool {
        didRequestAuthorization = true
        if !shouldGrantAuthorization {
            throw NSError(domain: "UNUserNotificationCenter", code: -1)
        }
        return shouldGrantAuthorization
    }
    
    override func add(_ request: UNNotificationRequest) async throws {
        if authorizationStatus != .authorized {
            throw NSError(domain: "UNUserNotificationCenter", code: -1)
        }
        addedRequests.append(request)
    }
    
    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        didRemoveRequests = true
        removedIdentifiers = identifiers
    }
    
    override func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return pendingRequests
    }
    
    override var supportsContentExtensions: Bool {
        return true
    }
} 