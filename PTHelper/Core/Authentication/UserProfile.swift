import Foundation

struct UserProfile: Codable, Equatable, Sendable {
    let id: UUID
    var username: String?
    var fullName: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}
