import Foundation
import AWSMobileClient
import Alamofire

enum AuthState {
    case signedIn
    case signedOut
    case signedUp
    case confirmSignUp
    case resetPassword
    case error(Error)
}

class AuthenticationManager: ObservableObject {
    @Published var authState: AuthState = .signedOut
    @Published var currentUser: User?
    
    static let shared = AuthenticationManager()
    private let apiClient = APIClient.shared
    
    private init() {
        // Initialize AWS Mobile Client
        AWSMobileClient.default().initialize { [weak self] userState, error in
            if let error = error {
                print("Error initializing AWSMobileClient: \(error.localizedDescription)")
                self?.updateAuthState(.error(error))
                return
            }
            
            if let userState = userState {
                switch userState {
                case .signedIn:
                    self?.updateAuthState(.signedIn)
                case .signedOut:
                    self?.updateAuthState(.signedOut)
                default:
                    self?.updateAuthState(.signedOut)
                }
            }
        }
    }
    
    func updateAuthState(_ state: AuthState) {
        DispatchQueue.main.async { [weak self] in
            self?.authState = state
            if case .signedIn = state {
                self?.fetchUserProfile()
            } else if case .signedOut = state {
                self?.currentUser = nil
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
                updateAuthState(.error(error))
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            AWSMobileClient.default().signIn(username: email, password: password) { result, error in
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
                    self.updateAuthState(.signedIn)
                    continuation.resume(returning: ())
                default:
                    continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected sign in state"]))
                }
            }
        }
    }
    
    func signUp(email: String, password: String, role: UserRole, parentId: String? = nil) async throws {
        let userAttributes = [
            "email": email,
            "custom:role": role.rawValue,
            "custom:parent_id": parentId
        ].compactMapValues { $0 }
        
        do {
            let signUpResult = try await AWSMobileClient.default().signUp(
                username: email,
                password: password,
                userAttributes: userAttributes
            )
            
            DispatchQueue.main.async {
                if signUpResult.signUpConfirmationState == .confirmed {
                    self.authState = .signedUp
                } else {
                    self.authState = .confirmSignUp
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.authState = .error(error)
            }
        }
    }
    
    func confirmSignUp(email: String, code: String) async throws {
        do {
            let confirmSignUpResult = try await AWSMobileClient.default().confirmSignUp(username: email, confirmationCode: code)
            
            DispatchQueue.main.async {
                if confirmSignUpResult.signUpConfirmationState == .confirmed {
                    self.authState = .signedUp
                } else {
                    self.authState = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Confirmation failed"]))
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.authState = .error(error)
            }
        }
    }
    
    func signOut() {
        AWSMobileClient.default().signOut()
        updateAuthState(.signedOut)
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await AWSMobileClient.default().forgotPassword(username: email)
            DispatchQueue.main.async {
                self.authState = .resetPassword
            }
        } catch {
            DispatchQueue.main.async {
                self.authState = .error(error)
            }
        }
    }
    
    func confirmResetPassword(email: String, newPassword: String, confirmationCode: String) async throws {
        do {
            try await AWSMobileClient.default().confirmForgotPassword(
                username: email,
                newPassword: newPassword,
                confirmationCode: confirmationCode
            )
            DispatchQueue.main.async {
                self.authState = .signedOut
            }
        } catch {
            DispatchQueue.main.async {
                self.authState = .error(error)
            }
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        do {
            try await AWSMobileClient.default().changePassword(
                currentPassword: currentPassword,
                proposedPassword: newPassword
            )
        } catch {
            throw error
        }
    }
    
    func deleteAccount() async throws {
        guard let username = AWSMobileClient.default().username else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        do {
            // Delete user data from DynamoDB
            try await deleteUserData(username)
            
            // Delete Cognito user
            try await AWSMobileClient.default().deleteUser()
            
            DispatchQueue.main.async {
                self.signOut()
            }
        } catch {
            throw error
        }
    }
    
    private func deleteUserData(_ userId: String) async throws {
        // In a real app, this would delete all user-related data from DynamoDB
        // For now, we'll just simulate the deletion
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
    }
} 