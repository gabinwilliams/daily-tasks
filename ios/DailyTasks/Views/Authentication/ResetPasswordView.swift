import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmationCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                if !showConfirmation {
                    // Request password reset
                    Section(header: Text("Enter your email to reset your password")) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                    
                    Section {
                        Button(action: requestReset) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Reset Password")
                            }
                        }
                        .disabled(isLoading || !isValidEmail)
                    }
                } else {
                    // Confirm password reset
                    Section(header: Text("Enter the confirmation code sent to your email")) {
                        TextField("Confirmation Code", text: $confirmationCode)
                            .keyboardType(.numberPad)
                        
                        SecureField("New Password", text: $newPassword)
                            .textContentType(.newPassword)
                    }
                    
                    Section {
                        Button(action: confirmReset) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Confirm")
                            }
                        }
                        .disabled(isLoading || !isValidConfirmation)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isValidEmail: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    private var isValidConfirmation: Bool {
        !confirmationCode.isEmpty && !newPassword.isEmpty && newPassword.count >= 8
    }
    
    private func requestReset() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.resetPassword(email: email)
                DispatchQueue.main.async {
                    showConfirmation = true
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func confirmReset() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.confirmResetPassword(
                    email: email,
                    newPassword: newPassword,
                    confirmationCode: confirmationCode
                )
                dismiss()
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
            .environmentObject(AuthenticationManager.shared)
    }
} 