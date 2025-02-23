import Foundation

enum TaskStatus: String, Codable {
    case pending
    case completed
    case approved
    case rejected
}

struct Task: Identifiable, Codable {
    let id: String
    let kidId: String
    var title: String
    var description: String
    var status: TaskStatus
    var photoUrl: String?
    var parentComment: String?
    let dueDate: Date
    let createdAt: Date
    var updatedAt: Date
    
    var isOverdue: Bool {
        dueDate < Date() && status == .pending
    }
    
    var canBeCompleted: Bool {
        status == .pending || status == .rejected
    }
    
    var canBeApproved: Bool {
        status == .completed
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "taskId"
        case kidId
        case title
        case description
        case status
        case photoUrl
        case parentComment
        case dueDate
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        kidId = try container.decode(String.self, forKey: .kidId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(TaskStatus.self, forKey: .status)
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        parentComment = try container.decodeIfPresent(String.self, forKey: .parentComment)
        
        let dateFormatter = ISO8601DateFormatter()
        
        let dueDateString = try container.decode(String.self, forKey: .dueDate)
        dueDate = dateFormatter.date(from: dueDateString) ?? Date()
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(kidId, forKey: .kidId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(photoUrl, forKey: .photoUrl)
        try container.encodeIfPresent(parentComment, forKey: .parentComment)
        
        let dateFormatter = ISO8601DateFormatter()
        
        try container.encode(dateFormatter.string(from: dueDate), forKey: .dueDate)
        try container.encode(dateFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(dateFormatter.string(from: updatedAt), forKey: .updatedAt)
    }
}

struct ReminderSettings: Codable {
    var enableUpcoming: Bool
    var upcomingMinutesBefore: Int
    var enableDueToday: Bool
    var dueTodayTime: Date
    var enableOverdue: Bool
    
    static let `default` = ReminderSettings(
        enableUpcoming: true,
        upcomingMinutesBefore: 60,
        enableDueToday: true,
        dueTodayTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
        enableOverdue: true
    )
    
    enum CodingKeys: String, CodingKey {
        case enableUpcoming
        case upcomingMinutesBefore
        case enableDueToday
        case dueTodayTime
        case enableOverdue
    }
    
    init(
        enableUpcoming: Bool,
        upcomingMinutesBefore: Int,
        enableDueToday: Bool,
        dueTodayTime: Date,
        enableOverdue: Bool
    ) {
        self.enableUpcoming = enableUpcoming
        self.upcomingMinutesBefore = upcomingMinutesBefore
        self.enableDueToday = enableDueToday
        self.dueTodayTime = dueTodayTime
        self.enableOverdue = enableOverdue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        enableUpcoming = try container.decode(Bool.self, forKey: .enableUpcoming)
        upcomingMinutesBefore = try container.decode(Int.self, forKey: .upcomingMinutesBefore)
        enableDueToday = try container.decode(Bool.self, forKey: .enableDueToday)
        enableOverdue = try container.decode(Bool.self, forKey: .enableOverdue)
        
        let dateFormatter = ISO8601DateFormatter()
        let dueTodayTimeString = try container.decode(String.self, forKey: .dueTodayTime)
        dueTodayTime = dateFormatter.date(from: dueTodayTimeString) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(enableUpcoming, forKey: .enableUpcoming)
        try container.encode(upcomingMinutesBefore, forKey: .upcomingMinutesBefore)
        try container.encode(enableDueToday, forKey: .enableDueToday)
        try container.encode(enableOverdue, forKey: .enableOverdue)
        
        let dateFormatter = ISO8601DateFormatter()
        try container.encode(dateFormatter.string(from: dueTodayTime), forKey: .dueTodayTime)
    }
} 