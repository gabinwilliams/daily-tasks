import Foundation
import AWSMobileClient
import Alamofire

class AuthenticationManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: User?
    
    static let shared = AuthenticationManager()
    private let apiClient = APIClient.shared
    
    private init() {
        // Initialize AWS Mobile Client
        AWSMobileClient.default().initialize { [weak self] userState, error in
            if let error = error {
                print("Error initializing AWSMobileClient: \(error.localizedDescription)")
                return
            }
            self?.updateAuthState(userState)
        }
    }
    
    func updateAuthState(_ state: AWSMobileClientState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .signedIn:
                self?.isSignedIn = true
                self?.fetchUserProfile()
            case .signedOut:
                self?.isSignedIn = false
                self?.currentUser = nil
            default:
                self?.isSignedIn = false
            }
        }
    }
    
    private func fetchUserProfile() {
        Task {
            do {
                let user = try await apiClient.getCurrentUser()
                DispatchQueue.main.async { [weak self] in
                    self?.currentUser = user
                }
            } catch {
                print("Error fetching user profile: \(error.localizedDescription)")
            }
        }
    }
    
    func signIn(username: String, password: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            AWSMobileClient.default().signIn(username: username, password: password) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result from sign in"]))
                    return
                }
                
                switch result.signInState {
                case .signedIn:
                    continuation.resume(returning: ())
                default:
                    continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected sign in state"]))
                }
            }
        }
    }
    
    func signOut() {
        AWSMobileClient.default().signOut()
    }
}

@unchecked Sendable
class AuthenticationInterceptor: RequestInterceptor {
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