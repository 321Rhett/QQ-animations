import Foundation
import SwiftUI

class QuestionViewModel: ObservableObject {
    @Published var currentQuestion: Question?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isFavorite: Bool = false
    @Published var isHidden: Bool = false
    
    private let databaseManager = DatabaseManager.shared
    
    init() {
        fetchRandomQuestion()
    }
    
    func fetchRandomQuestion() {
        isLoading = true
        errorMessage = nil
        
        // Small delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let question = self.databaseManager.getRandomQuestion() {
                self.currentQuestion = question
                
                // Check for any existing preferences
                if let preference = self.databaseManager.getQuestionPreference(questionId: question.id) {
                    self.isFavorite = preference.isFavorite
                    self.isHidden = preference.isHidden
                } else {
                    // Reset preferences for new question
                    self.isFavorite = false
                    self.isHidden = false
                }
            } else {
                self.errorMessage = "Could not load a question"
            }
            self.isLoading = false
        }
    }
    
    // Toggle favorite status
    func toggleFavorite() {
        guard let question = currentQuestion else { return }
        
        // Update in memory
        isFavorite.toggle()
        if isFavorite {
            isHidden = false // Can't be both favorite and hidden
        }
        
        // Save to database
        _ = databaseManager.updateQuestionPreference(
            questionId: question.id,
            isFavorite: isFavorite,
            isHidden: isHidden
        )
    }
    
    // Toggle hidden status
    func toggleHidden() {
        guard let question = currentQuestion else { return }
        
        // Update in memory
        isHidden.toggle()
        if isHidden {
            isFavorite = false // Can't be both favorite and hidden
        }
        
        // Save to database
        _ = databaseManager.updateQuestionPreference(
            questionId: question.id,
            isFavorite: isFavorite,
            isHidden: isHidden
        )
    }
    
    // For debugging
    var questionDisplayText: String {
        if isLoading {
            return "Loading..."
        } else if let error = errorMessage {
            return "Error: \(error)"
        } else if let question = currentQuestion {
            return question.questionText
        } else {
            return "No question available"
        }
    }
} 