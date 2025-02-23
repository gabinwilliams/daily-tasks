import SwiftUI

struct TaskListView: View {
    @StateObject var viewModel: TaskListViewModel
    @State private var showingNewTask = false
    @State private var selectedTask: Task?
    @State private var showingFilter = false
    @State private var showingStats = false
    @State private var sortOrder: SortOrder = .dueDate
    
    private var filteredAndSortedTasks: [Task] {
        let filtered = viewModel.tasks
        
        return filtered.sorted { first, second in
            switch sortOrder {
            case .dueDate:
                return first.dueDate < second.dueDate
            case .status:
                return first.status.rawValue < second.status.rawValue
            case .createdAt:
                return first.createdAt > second.createdAt
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView()
                } else if viewModel.tasks.isEmpty {
                    EmptyStateView(
                        title: "No Tasks",
                        message: "Tasks you create or are assigned to you will appear here.",
                        systemImage: "checklist"
                    )
                } else {
                    taskList
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(SortOrder.allCases) { order in
                                Label(order.description, systemImage: order.icon)
                                    .tag(order)
                            }
                        }
                        
                        Divider()
                        
                        Menu("Filter Status") {
                            Button("All") {
                                viewModel.setFilter(nil)
                            }
                            
                            ForEach(TaskStatus.allCases) { status in
                                Button {
                                    viewModel.setFilter(status)
                                } label: {
                                    if viewModel.filterStatus == status {
                                        Label(status.description, systemImage: "checkmark")
                                    } else {
                                        Text(status.description)
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if viewModel.userRole == .parent {
                            Button {
                                showingStats = true
                            } label: {
                                Image(systemName: "chart.bar")
                            }
                        }
                        
                        if viewModel.userRole == .parent {
                            Button {
                                showingNewTask = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewTask) {
                NewTaskView()
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .sheet(isPresented: $showingStats) {
                NavigationView {
                    TaskStatisticsView()
                }
            }
            .refreshable {
                viewModel.fetchTasks()
            }
        }
    }
    
    private var taskList: some View {
        List {
            ForEach(filteredAndSortedTasks) { task in
                TaskRowView(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTask = task
                    }
                    .onAppear {
                        viewModel.loadMoreTasksIfNeeded(currentTask: task)
                    }
            }
            .listRowSeparator(.hidden)
            
            if viewModel.hasMoreTasks {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Supporting Types

enum SortOrder: String, CaseIterable, Identifiable {
    case dueDate
    case status
    case createdAt
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .dueDate: return "Due Date"
        case .status: return "Status"
        case .createdAt: return "Created Date"
        }
    }
    
    var icon: String {
        switch self {
        case .dueDate: return "calendar"
        case .status: return "checkmark.circle"
        case .createdAt: return "clock"
        }
    }
}

extension TaskStatus: Identifiable {
    public var id: String { rawValue }
    
    var description: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
}

struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView(viewModel: TaskListViewModel(userRole: .parent))
            .environmentObject(TaskManager.shared)
    }
} 