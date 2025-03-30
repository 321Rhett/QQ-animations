import Foundation
import SwiftUI

class QuestionViewModel: ObservableObject {
    @Published var currentQuestion: Question?
    @Published var questionPreference: UserPreference?
    
    private let databaseManager = DatabaseManager.shared
    
    // Add computed properties for ContentView to bind to
    var questionDisplayText: String {
        currentQuestion?.questionText ?? "No question available"
    }
    
    var isFavorite: Bool {
        questionPreference?.isFavorite ?? false
    }
    
    var isHidden: Bool {
        questionPreference?.isHidden ?? false
    }
    
    init() {
        loadRandomQuestion()
    }
    
    // Function needed for ContentView binding
    func fetchRandomQuestion() {
        loadRandomQuestion()
    }
    
    // Load a random question from the database
    func loadRandomQuestion() {
        // Try to get a random question from the database
        if let question = self.databaseManager.getRandomQuestion() {
            self.currentQuestion = question
            
            // Get preference for this question
            if let preference = self.databaseManager.getQuestionPreference(questionId: question.id) {
                self.questionPreference = preference
            } else {
                // If no preference exists, create a default one
                self.questionPreference = UserPreference(questionId: question.id)
            }
        } else {
            // If we couldn't get a question, use a placeholder
            self.currentQuestion = Question(
                id: 0,
                questionText: "No questions available. Please check the database.",
                pack: "none",
                versionAdded: "1.0",
                tags: ""
            )
            self.questionPreference = UserPreference(questionId: 0)
        }
    }
    
    // Toggle favorite status
    func toggleFavorite() {
        guard let question = currentQuestion, var preference = questionPreference else {
            return
        }
        
        preference.isFavorite.toggle()
        self.questionPreference = preference
        
        // Save to database
        _ = databaseManager.updateQuestionPreference(
            questionId: question.id,
            isFavorite: preference.isFavorite,
            isHidden: preference.isHidden
        )
        
        // Force UI update
        objectWillChange.send()
    }
    
    // Toggle hidden status
    func toggleHidden() {
        guard let question = currentQuestion, var preference = questionPreference else {
            return
        }
        
        preference.isHidden.toggle()
        self.questionPreference = preference
        
        // Save to database
        _ = databaseManager.updateQuestionPreference(
            questionId: question.id,
            isFavorite: preference.isFavorite,
            isHidden: preference.isHidden
        )
        
        // Force UI update
        objectWillChange.send()
    }
} 