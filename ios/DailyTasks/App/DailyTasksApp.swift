import SwiftUI
import AWSMobileClient

@main
struct DailyTasksApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var taskManager = TaskManager.shared
    
    init() {
        configureAWS()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(taskManager)
        }
    }
    
    private func configureAWS() {
        AWSMobileClient.default().initialize { userState, error in
            if let error = error {
                print("AWS initialization error: \(error.localizedDescription)")
                return
            }
            
            if let userState = userState {
                authManager.updateAuthState(userState)
            }
        }
    }
} 