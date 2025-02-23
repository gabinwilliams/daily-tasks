import SwiftUI

struct TaskRowView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.headline)
                
                Spacer()
                
                statusBadge
            }
            
            Text(task.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(dueDateText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(task.isOverdue ? .red : .secondary)
                
                if task.photoUrl != nil {
                    Label("Photo attached", systemImage: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var statusBadge: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch task.status {
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
    
    private var statusText: String {
        task.status.rawValue.capitalized
    }
    
    private var dueDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: task.dueDate)
    }
}

struct TaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        TaskRowView(task: Task(
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
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 