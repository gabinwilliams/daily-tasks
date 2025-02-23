import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingSuccess = false
    
    private var isValidInput: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Password")) {
                    SecureField("Enter current password", text: $currentPassword)
                        .textContentType(.password)
                }
                
                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm new password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                if !newPassword.isEmpty {
                    Section(footer: Text("Password must be at least 8 characters long")) {
                        PasswordStrengthView(password: newPassword)
                    }
                }
                
                Section {
                    Button {
                        changePassword()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Change Password")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValidInput || isLoading)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isLoading)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been successfully changed.")
            }
        }
    }
    
    private func changePassword() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await authManager.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                showingSuccess = true
            } catch {
                self.error = error
                showingError = true
            }
            isLoading = false
        }
    }
}

struct PasswordStrengthView: View {
    let password: String
    
    private var strength: PasswordStrength {
        if password.isEmpty { return .empty }
        if password.count < 8 { return .tooShort }
        
        var score = 0
        
        // Check for numbers
        if password.contains(where: { $0.isNumber }) {
            score += 1
        }
        
        // Check for lowercase letters
        if password.contains(where: { $0.isLowercase }) {
            score += 1
        }
        
        // Check for uppercase letters
        if password.contains(where: { $0.isUppercase }) {
            score += 1
        }
        
        // Check for special characters
        let specialCharacters = CharacterSet.punctuationCharacters.union(.symbols)
        if password.unicodeScalars.contains(where: { specialCharacters.contains($0) }) {
            score += 1
        }
        
        switch score {
        case 4: return .strong
        case 3: return .good
        case 2: return .fair
        default: return .weak
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password Strength: \(strength.description)")
                .foregroundColor(strength.color)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(strength.color)
                        .frame(width: geometry.size.width * strength.percentage, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    private enum PasswordStrength {
        case empty
        case tooShort
        case weak
        case fair
        case good
        case strong
        
        var description: String {
            switch self {
            case .empty: return "Empty"
            case .tooShort: return "Too Short"
            case .weak: return "Weak"
            case .fair: return "Fair"
            case .good: return "Good"
            case .strong: return "Strong"
            }
        }
        
        var color: Color {
            switch self {
            case .empty, .tooShort: return .secondary
            case .weak: return .red
            case .fair: return .orange
            case .good: return .yellow
            case .strong: return .green
            }
        }
        
        var percentage: Double {
            switch self {
            case .empty: return 0.0
            case .tooShort: return 0.2
            case .weak: return 0.4
            case .fair: return 0.6
            case .good: return 0.8
            case .strong: return 1.0
            }
        }
    }
}

struct ChangePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ChangePasswordView()
            .environmentObject(AuthenticationManager.shared)
    }
} 