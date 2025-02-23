import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var role: UserRole = .kid
    @State private var parentId = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section {
                    Picker("Role", selection: $role) {
                        Text("Parent").tag(UserRole.parent)
                        Text("Kid").tag(UserRole.kid)
                    }
                    
                    if role == .kid {
                        TextField("Parent ID", text: $parentId)
                            .autocapitalization(.none)
                    }
                }
                
                Section {
                    Button(action: signUp) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Sign Up")
                        }
                    }
                    .disabled(isLoading || !isValidInput)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Sign Up")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isValidInput: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 8 &&
        email.contains("@") &&
        (role == .parent || !parentId.isEmpty)
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signUp(
                    email: email,
                    password: password,
                    role: role,
                    parentId: role == .kid ? parentId : nil
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

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthenticationManager.shared)
    }
} 