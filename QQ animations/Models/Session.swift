import Foundation

struct Session: Identifiable, Equatable {
    let id: Int
    let name: String
    let creationDate: Date
    
    // Initialize with defaults
    init(id: Int, name: String, creationDate: Date = Date()) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
    }
    
    // Implement Equatable
    static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.id == rhs.id
    }
} 