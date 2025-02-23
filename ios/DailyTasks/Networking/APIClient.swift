import Foundation
import Alamofire
import AWSMobileClient

enum APIError: Error {
    case invalidURL
    case decodingError
    case networkError(Error)
    case serverError(String)
    case unauthorized
}

class APIClient {
    static let shared = APIClient()
    
    private let baseURL = "https://api.example.com/v1" // Replace with your actual API URL
    private let session: Session
    private var authToken: String?
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        session = Session(
            configuration: configuration,
            interceptor: AuthenticationInterceptor()
        )
    }
    
    // MARK: - Tasks
    
    func getTasks(params: TaskQueryParams = TaskQueryParams(limit: 20, nextToken: nil, status: nil, fromDate: nil, toDate: nil)) async throws -> TasksResponse {
        return try await withCheckedThrowingContinuation { continuation in
            session.request("\(baseURL)/tasks",
                          method: .get,
                          parameters: params.parameters,
                          encoding: URLEncoding.default)
                .validate()
                .responseDecodable(of: TasksResponse.self) { response in
                    switch response.result {
                    case .success(let tasksResponse):
                        continuation.resume(returning: tasksResponse)
                    case .failure(let error):
                        continuation.resume(throwing: self.handleError(error))
                    }
                }
        }
    }
    
    func createTask(title: String, description: String, dueDate: Date, kidId: String) async throws -> Task {
        let parameters: [String: Any] = [
            "title": title,
            "description": description,
            "dueDate": ISO8601DateFormatter().string(from: dueDate),
            "kidId": kidId
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request("\(baseURL)/tasks",
                          method: .post,
                          parameters: parameters,
                          encoding: JSONEncoding.default)
                .validate()
                .responseDecodable(of: Task.self) { response in
                    switch response.result {
                    case .success(let task):
                        continuation.resume(returning: task)
                    case .failure(let error):
                        continuation.resume(throwing: self.handleError(error))
                    }
                }
        }
    }
    
    func updateTask(_ task: Task) async throws -> Task {
        let parameters = try JSONEncoder().encode(task)
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request("\(baseURL)/tasks/\(task.id)",
                          method: .put,
                          parameters: parameters,
                          encoding: JSONEncoding.default)
                .validate()
                .responseDecodable(of: Task.self) { response in
                    switch response.result {
                    case .success(let updatedTask):
                        continuation.resume(returning: updatedTask)
                    case .failure(let error):
                        continuation.resume(throwing: self.handleError(error))
                    }
                }
        }
    }
    
    func deleteTask(_ taskId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            session.request("\(baseURL)/tasks/\(taskId)",
                          method: .delete)
                .validate()
                .response { response in
                    if let error = response.error {
                        continuation.resume(throwing: self.handleError(error))
                    } else {
                        continuation.resume()
                    }
                }
        }
    }
    
    // MARK: - Photo Upload
    
    func getPhotoUploadUrl(taskId: String) async throws -> PhotoUploadData {
        let parameters = ["taskId": taskId]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request("\(baseURL)/tasks/upload-url",
                          method: .post,
                          parameters: parameters,
                          encoding: JSONEncoding.default)
                .validate()
                .responseDecodable(of: PhotoUploadData.self) { response in
                    switch response.result {
                    case .success(let uploadData):
                        continuation.resume(returning: uploadData)
                    case .failure(let error):
                        continuation.resume(throwing: self.handleError(error))
                    }
                }
        }
    }
    
    // MARK: - Task Stats
    
    func getTaskStats(timeRange: TimeRange = .week, kidId: String? = nil) async throws -> TaskStats {
        var queryItems = [URLQueryItem(name: "timeRange", value: timeRange.rawValue)]
        if let kidId = kidId {
            queryItems.append(URLQueryItem(name: "kidId", value: kidId))
        }
        
        let request = try URLRequest(url: "\(baseURL)/tasks/stats", method: .get, queryItems: queryItems)
        return try await performRequest(request)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: AFError) -> APIError {
        switch error {
        case .responseValidationFailed(let reason):
            switch reason {
            case .unacceptableStatusCode(let code):
                if code == 401 {
                    return .unauthorized
                }
                return .serverError("Server returned status code \(code)")
            default:
                return .networkError(error)
            }
        case .responseSerializationFailed:
            return .decodingError
        default:
            return .networkError(error)
        }
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(request)
                .validate()
                .responseDecodable(of: T.self) { response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}

actor AuthenticationInterceptor: RequestInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let token = AWSMobileClient.default().getTokens()?.idToken?.tokenString else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token available"])))
            return
        }
        
        var urlRequest = urlRequest
        urlRequest.headers.add(.authorization(bearerToken: token))
        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        completion(.doNotRetry)
    }
}

private extension URLRequest {
    init(url: String, method: HTTPMethod, queryItems: [URLQueryItem] = [], body: Encodable? = nil) throws {
        var components = URLComponents(string: url)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        self.init(url: components.url!)
        httpMethod = method.rawValue
        
        if let body = body {
            httpBody = try JSONEncoder().encode(body)
            setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
    }
}

// MARK: - Response Types

struct TasksResponse: Codable {
    let items: [Task]
    let count: Int
    let nextToken: String?
}

struct PhotoUploadData: Codable {
    let uploadUrl: String
    let photoUrl: String
    let bucket: String
    let key: String
    let expiresIn: Int
}

// MARK: - Request Types

struct TaskQueryParams {
    let limit: Int
    let nextToken: String?
    let status: TaskStatus?
    let fromDate: Date?
    let toDate: Date?
    
    var parameters: [String: Any] {
        var params: [String: Any] = ["limit": limit]
        if let nextToken = nextToken {
            params["nextToken"] = nextToken
        }
        if let status = status {
            params["status"] = status.rawValue
        }
        if let fromDate = fromDate {
            params["fromDate"] = ISO8601DateFormatter().string(from: fromDate)
        }
        if let toDate = toDate {
            params["toDate"] = ISO8601DateFormatter().string(from: toDate)
        }
        return params
    }
} 