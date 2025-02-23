import Foundation
import Combine
import AWSS3

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func fetchTasks(params: TaskQueryParams = TaskQueryParams(limit: 20, nextToken: nil, status: nil, fromDate: nil, toDate: nil)) async throws -> TasksResponse {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiClient.getTasks(params: params)
            DispatchQueue.main.async {
                if params.nextToken == nil {
                    self.tasks = response.items
                } else {
                    self.tasks.append(contentsOf: response.items)
                }
                self.isLoading = false
            }
            return response
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    func createTask(title: String, description: String, dueDate: Date, kidId: String) async throws -> Task {
        isLoading = true
        error = nil
        
        do {
            let task = try await apiClient.createTask(
                title: title,
                description: description,
                dueDate: dueDate,
                kidId: kidId
            )
            
            DispatchQueue.main.async {
                self.tasks.append(task)
                self.isLoading = false
            }
            
            return task
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    func updateTask(_ task: Task) async throws {
        isLoading = true
        error = nil
        
        do {
            let updatedTask = try await apiClient.updateTask(task)
            
            DispatchQueue.main.async {
                if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[index] = updatedTask
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    func deleteTask(_ task: Task) async throws {
        isLoading = true
        error = nil
        
        do {
            try await apiClient.deleteTask(task.id)
            
            DispatchQueue.main.async {
                self.tasks.removeAll { $0.id == task.id }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    func uploadPhoto(for task: Task, imageData: Data) async throws -> String {
        isLoading = true
        error = nil
        
        do {
            let uploadData = try await apiClient.getPhotoUploadUrl(taskId: task.id)
            
            // Upload to S3
            let transferUtility = AWSS3TransferUtility.default()
            let expression = AWSS3TransferUtilityUploadExpression()
            expression.progressBlock = { _, progress in
                print("Upload progress: \(progress.fractionCompleted)")
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                transferUtility.uploadData(
                    imageData,
                    bucket: uploadData.bucket,
                    key: uploadData.key,
                    contentType: "image/jpeg",
                    expression: expression
                ) { task in
                    if let error = task.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            // Update task with photo URL
            var updatedTask = task
            updatedTask.photoUrl = uploadData.photoUrl
            try await updateTask(updatedTask)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            return uploadData.photoUrl
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    func approveTask(_ task: Task) async throws {
        var updatedTask = task
        updatedTask.status = .approved
        try await updateTask(updatedTask)
    }
    
    func rejectTask(_ task: Task, comment: String) async throws {
        var updatedTask = task
        updatedTask.status = .rejected
        updatedTask.parentComment = comment
        try await updateTask(updatedTask)
    }
    
    func markTaskAsCompleted(_ task: Task) async throws {
        var updatedTask = task
        updatedTask.status = .completed
        try await updateTask(updatedTask)
    }
    
    func updateTaskStatus(_ task: Task, newStatus: TaskStatus) async throws -> Task {
        try await apiClient.updateTaskStatus(task.id, newStatus: newStatus)
    }
} 