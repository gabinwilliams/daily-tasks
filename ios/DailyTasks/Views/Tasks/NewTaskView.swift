import SwiftUI

struct NewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskListViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var selectedKidId = ""
    @State private var showingError = false
    @State private var showingNotificationPermissionAlert = false
    @State private var errorMessage = ""
    
    init(viewModel: TaskListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $description)
                        .frame(height: 100)
                    DatePicker("Due Date", selection: $dueDate, in: Date()...)
                }
                
                Section(header: Text("Assign To")) {
                    KidPicker(selectedKidId: $selectedKidId)
                }
                
                Section {
                    Button("Create Task") {
                        createTask()
                    }
                    .disabled(title.isEmpty || selectedKidId.isEmpty)
                }
            }
            .navigationTitle("New Task")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Enable Notifications", isPresented: $showingNotificationPermissionAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("To receive reminders for this task, please enable notifications in Settings.")
            }
            .task {
                await notificationManager.checkAuthorizationStatus()
            }
        }
    }
    
    private func createTask() {
        Task {
            do {
                let task = try await viewModel.createTask(
                    title: title,
                    description: description,
                    dueDate: dueDate,
                    kidId: selectedKidId
                )
                
                if !notificationManager.isAuthorized {
                    showingNotificationPermissionAlert = true
                }
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

extension TaskListViewModel {
    var kids: [User] {
        // In a real app, this would fetch kids from a UserManager or similar
        // For now, we'll return an empty array
        []
    }
}

struct NewTaskView_Previews: PreviewProvider {
    static var previews: some View {
        NewTaskView(viewModel: TaskListViewModel(userRole: .parent))
            .environmentObject(TaskManager.shared)
    }
} 