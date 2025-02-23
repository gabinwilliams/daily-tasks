import SwiftUI

struct HelpView: View {
    @State private var selectedQuestion: FAQ?
    @State private var showingContactForm = false
    
    private let faqs = [
        FAQ(
            question: "How do tasks work?",
            answer: "Tasks are daily activities that need to be completed. Kids can mark tasks as completed and provide photo proof. Parents can then review and approve or reject the tasks."
        ),
        FAQ(
            question: "How does device control work?",
            answer: "When tasks are completed and approved, kids' devices are automatically granted WiFi access. If tasks are incomplete or rejected, device access is restricted."
        ),
        FAQ(
            question: "How do I add a device?",
            answer: "Parents can add devices in the Devices tab. You'll need the device's MAC address, which can be found in the device's network settings."
        ),
        FAQ(
            question: "What happens if I reject a task?",
            answer: "When rejecting a task, you can provide a reason. The child will need to complete the task again, addressing the feedback provided."
        ),
        FAQ(
            question: "Can I customize notification times?",
            answer: "Yes, you can set custom reminder times in the Settings tab under Notifications."
        ),
        FAQ(
            question: "How secure is my data?",
            answer: "We use industry-standard encryption and AWS security best practices to protect your data. All communications are encrypted, and data is stored securely."
        )
    ]
    
    var body: some View {
        List {
            Section {
                Text("Need help with Daily Tasks? Find answers to common questions below or contact our support team.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section("Frequently Asked Questions") {
                ForEach(faqs) { faq in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { selectedQuestion?.id == faq.id },
                            set: { isExpanded in
                                selectedQuestion = isExpanded ? faq : nil
                            }
                        )
                    ) {
                        Text(faq.answer)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } label: {
                        Text(faq.question)
                            .font(.headline)
                    }
                }
            }
            
            Section {
                Button {
                    showingContactForm = true
                } label: {
                    Label("Contact Support", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContactForm) {
            ContactSupportView()
        }
    }
}

struct FAQ: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var error: Error?
    @State private var showingError = false
    
    private var isValidInput: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        !subject.isEmpty &&
        !message.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Subject", text: $subject)
                }
                
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button {
                        submitSupportRequest()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Submit")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValidInput || isLoading)
                }
            }
            .navigationTitle("Contact Support")
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
                Text("Your support request has been submitted. We'll get back to you soon.")
            }
        }
    }
    
    private func submitSupportRequest() {
        isLoading = true
        error = nil
        
        // In a real app, this would send the support request to a backend service
        // For now, we'll just simulate a network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            showingSuccess = true
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HelpView()
        }
    }
} 