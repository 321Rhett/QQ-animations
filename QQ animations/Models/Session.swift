import Foundation

struct Session: Identifiable {
    let id: Int
    let name: String
    let creationDate: Date
    
    // Initialize with defaults
    init(id: Int, name: String, creationDate: Date = Date()) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
    }
} 