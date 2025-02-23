import Foundation

enum DeviceType: String, Codable, CaseIterable {
    case ps4 = "ps4"
    case tablet = "tablet"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .ps4:
            return "PlayStation 4"
        case .tablet:
            return "Tablet"
        case .other:
            return "Other Device"
        }
    }
    
    var icon: String {
        switch self {
        case .ps4:
            return "gamecontroller"
        case .tablet:
            return "ipad"
        case .other:
            return "laptopcomputer"
        }
    }
}

struct Device: Identifiable, Codable {
    let kidId: String
    let macAddress: String
    var deviceName: String
    var deviceType: DeviceType
    var isBlocked: Bool
    let createdAt: Date
    var updatedAt: Date
    
    var id: String { macAddress }
    
    enum CodingKeys: String, CodingKey {
        case kidId
        case macAddress
        case deviceName
        case deviceType
        case isBlocked
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        kidId = try container.decode(String.self, forKey: .kidId)
        macAddress = try container.decode(String.self, forKey: .macAddress)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        deviceType = try container.decode(DeviceType.self, forKey: .deviceType)
        isBlocked = try container.decode(Bool.self, forKey: .isBlocked)
        
        let dateFormatter = ISO8601DateFormatter()
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(kidId, forKey: .kidId)
        try container.encode(macAddress, forKey: .macAddress)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(isBlocked, forKey: .isBlocked)
        
        let dateFormatter = ISO8601DateFormatter()
        
        try container.encode(dateFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(dateFormatter.string(from: updatedAt), forKey: .updatedAt)
    }
} 