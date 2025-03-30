import Foundation

struct UserPreference {
    let questionId: Int
    var isFavorite: Bool
    var isHidden: Bool
    var isCompleted: Bool
    var lastShownDate: Date?
    
    // Initialize with defaults
    init(questionId: Int, isFavorite: Bool = false, isHidden: Bool = false, isCompleted: Bool = false, lastShownDate: Date? = nil) {
        self.questionId = questionId
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.isCompleted = isCompleted
        self.lastShownDate = lastShownDate
    }
} 