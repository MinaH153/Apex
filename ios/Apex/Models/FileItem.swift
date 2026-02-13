import Foundation

struct FileItem: Identifiable, Codable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let path: String
    let size: Int64?
    let mimeType: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case path
        case size
        case mimeType = "mime_type"
        case createdAt = "created_at"
    }
}
