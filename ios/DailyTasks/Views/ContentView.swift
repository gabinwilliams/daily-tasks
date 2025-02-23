import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .signedIn:
                if let user = authManager.currentUser {
                    if user.isParent {
                        ParentTabView()
                    } else {
                        KidTabView()
                    }
                }
            case .signedOut:
                SignInView()
            case .signedUp:
                SignInView()
            case .confirmSignUp:
                ConfirmSignUpView()
            case .resetPassword:
                ResetPasswordView()
            case .error(let error):
                ErrorView(error: error)
            }
        }
        .animation(.easeInOut, value: authManager.authState)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(TaskManager.shared)
    }
} 