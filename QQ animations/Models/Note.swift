import Foundation

struct Note: Identifiable, Equatable {
    let id: Int
    let sessionId: Int
    let questionId: Int
    let content: String
    let createdAt: Date
    
    init(id: Int, sessionId: Int, questionId: Int, content: String, createdAt: Date = Date()) {
        self.id = id
        self.sessionId = sessionId
        self.questionId = questionId
        self.content = content
        self.createdAt = createdAt
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id
    }
} 