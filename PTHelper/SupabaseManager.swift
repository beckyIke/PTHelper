import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: SupabaseConfig.url)!,
    supabaseKey: SupabaseConfig.anonKey
)

struct UserProfile: Codable, Equatable, Sendable {
    let id: UUID
    var username: String?
    var fullName: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName  = "full_name"
        case avatarUrl = "avatar_url"
    }
}
