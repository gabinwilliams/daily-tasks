import SwiftUI
import SDWebImage

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var viewModel: TaskListViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingDeleteConfirmation = false
    @State private var showingReminderSettings = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var showingRejectAlert = false
    @State private var rejectionComment = ""
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingNotificationPermissionAlert = false
    
    let task: Task
    
    init(task: Task) {
        self.task = task
        _viewModel = StateObject(wrappedValue: TaskListViewModel(userRole: .parent))
    }
    
    var body: some View {
        NavigationView {
            List {
                // Task Details
                Section {
                    taskInfoRow("Title", task.title)
                    taskInfoRow("Description", task.description)
                    taskInfoRow("Status", task.status.rawValue.capitalized)
                    taskInfoRow("Due Date", task.dueDate.formatted())
                }
                
                // Photo Section
                Section("Photo") {
                    if let photoUrl = task.photoUrl {
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxHeight: 200)
                    } else if canUploadPhoto {
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label("Add Photo", systemImage: "camera")
                        }
                    } else {
                        Text("No photo attached")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Parent Comment
                if let comment = task.parentComment {
                    Section("Parent Comment") {
                        Text(comment)
                    }
                }
                
                // Actions
                Section {
                    if task.canBeCompleted {
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label("Add Photo Proof", systemImage: "camera")
                        }
                    }
                    
                    if viewModel.userRole == .parent && task.canBeApproved {
                        Group {
                            Button {
                                approveTask()
                            } label: {
                                Label("Approve Task", systemImage: "checkmark.circle")
                                    .foregroundColor(.green)
                            }
                            
                            Button(role: .destructive) {
                                showingRejectAlert = true
                            } label: {
                                Label("Reject Task", systemImage: "xmark.circle")
                                    .foregroundColor(.red)
                            }
                        }
                        .disabled(!task.canBeApproved)
                    }
                    
                    Button {
                        if !notificationManager.isAuthorized {
                            showingNotificationPermissionAlert = true
                        } else {
                            showingReminderSettings = true
                        }
                    } label: {
                        Label("Manage Reminders", systemImage: "bell")
                    }
                }
                
                // Danger Zone
                if viewModel.userRole == .parent {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }
                }
                
                // Metadata
                Section {
                    taskInfoRow("Created", task.createdAt.formatted())
                    taskInfoRow("Last Updated", task.updatedAt.formatted())
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
            .alert("Delete Task", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
            .sheet(isPresented: $showingReminderSettings) {
                TaskReminderSettingsView(task: task) { settings in
                    updateReminderSettings(settings)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImageSourcePicker(image: $selectedImage, isPresented: $showingImagePicker)
            }
            .alert("Reject Task", isPresented: $showingRejectAlert) {
                TextField("Comment", text: $rejectionComment)
                Button("Cancel", role: .cancel) { }
                Button("Reject", role: .destructive) {
                    rejectTask()
                }
            } message: {
                Text("Please provide a reason for rejecting this task.")
            }
            .alert("Enable Notifications", isPresented: $showingNotificationPermissionAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Notifications are required for reminders. Would you like to enable them in Settings?")
            }
            .task {
                await notificationManager.checkAuthorizationStatus()
            }
            .onChange(of: selectedImage) { _ in
                if let image = selectedImage {
                    uploadPhoto(image)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private var canUploadPhoto: Bool {
        guard let currentUser = authManager.currentUser else { return false }
        return currentUser.role == .kid && task.canBeCompleted
    }
    
    private var canTakeAction: Bool {
        guard let currentUser = authManager.currentUser else { return false }
        
        switch currentUser.role {
        case .kid:
            return task.canBeCompleted
        case .parent:
            return task.canBeApproved
        }
    }
    
    private func taskInfoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
    
    private func uploadPhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await viewModel.uploadPhoto(for: task, imageData: imageData)
                selectedImage = nil
                isLoading = false
            } catch {
                self.error = error
                self.showingError = true
                isLoading = false
            }
        }
    }
    
    private func deleteTask() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await viewModel.deleteTask(task)
                dismiss()
            } catch {
                self.error = error
                showingError = true
                isLoading = false
            }
        }
    }
    
    private func approveTask() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await viewModel.approveTask(task)
                dismiss()
            } catch {
                self.error = error
                showingError = true
                isLoading = false
            }
        }
    }
    
    private func rejectTask() {
        guard !rejectionComment.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                try await viewModel.rejectTask(task, comment: rejectionComment)
                dismiss()
            } catch {
                self.error = error
                showingError = true
                isLoading = false
            }
        }
    }
    
    private func updateReminderSettings(_ settings: ReminderSettings) {
        isLoading = true
        error = nil
        
        Task {
            do {
                var updatedTask = task
                updatedTask.reminderSettings = settings
                try await viewModel.updateTask(updatedTask)
                dismiss()
            } catch {
                self.error = error
                showingError = true
                isLoading = false
            }
        }
    }
}

struct TaskStatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.1))
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .completed:
            return .blue
        case .approved:
            return .green
        case .rejected:
            return .red
        }
    }
}

struct TaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TaskDetailView(task: Task(
            id: "1",
            kidId: "kid1",
            title: "Clean Room",
            description: "Make your bed and organize your desk",
            status: .pending,
            photoUrl: nil,
            parentComment: nil,
            dueDate: Date().addingTimeInterval(3600),
            createdAt: Date(),
            updatedAt: Date()
        ))
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(TaskManager.shared)
    }
} 