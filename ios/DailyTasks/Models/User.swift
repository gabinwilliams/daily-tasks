import Foundation

enum UserRole: String, Codable {
    case parent
    case kid
}

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let role: UserRole
    var parentId: String?
    
    var isParent: Bool {
        role == .parent
    }
} 