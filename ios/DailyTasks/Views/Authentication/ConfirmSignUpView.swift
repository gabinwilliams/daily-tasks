import SwiftUI

struct ConfirmSignUpView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var confirmationCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section(header: Text("Enter the confirmation code sent to your email")) {
                TextField("Confirmation Code", text: $confirmationCode)
                    .keyboardType(.numberPad)
            }
            
            Section {
                Button(action: confirmSignUp) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Confirm")
                    }
                }
                .disabled(isLoading || confirmationCode.isEmpty)
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Confirm Sign Up")
    }
    
    private func confirmSignUp() {
        guard let email = UserDefaults.standard.string(forKey: "tempEmail") else {
            errorMessage = "Email not found. Please try signing up again."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.confirmSignUp(email: email, code: confirmationCode)
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct ConfirmSignUpView_Previews: PreviewProvider {
    static var previews: some View {
        ConfirmSignUpView()
            .environmentObject(AuthenticationManager.shared)
    }
} 