import Foundation
import SwiftUI

class QuestionViewModel: ObservableObject {
    @Published var currentQuestion: Question?
    @Published var questionPreference: UserPreference?
    @Published var completedQuestions: [Int] = []
    @Published var totalQuestions: Int = 0
    @Published var completedCount: Int = 0
    @Published var favoritesFilterState: FilterState = .none
    
    private var allQuestionsCount: Int = 0 // Store the absolute total count
    private var hiddenQuestionsCount: Int = 0
    
    private let databaseManager = DatabaseManager.shared
    private let sessionId: Int
    
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
    
    var progressText: String {
        // Total count should reflect the current filter
        let currentTotal = calculateFilteredTotal()
        return "\(completedCount)/\(currentTotal)"
    }
    
    init(sessionId: Int = -1) {
        self.sessionId = sessionId
        loadQuestionCounts()
    }
    
    // Load initial question counts
    private func loadQuestionCounts() {
        print("VM: Loading question counts for session \(sessionId)")
        // Get the absolute total number of questions in the database
        allQuestionsCount = databaseManager.getQuestionCount()
        print("VM: allQuestionsCount = \(allQuestionsCount)")
        hiddenQuestionsCount = databaseManager.getHiddenQuestionCount()
        print("VM: hiddenQuestionsCount = \(hiddenQuestionsCount)")
        
        // Calculate the total *initially* available questions (total - hidden)
        // Filtered total will be calculated separately
        totalQuestions = allQuestionsCount - hiddenQuestionsCount
        print("VM: Base totalQuestions (all - hidden) = \(totalQuestions)")
        
        // If we have a valid session, get completed questions
        if sessionId > 0 {
            // Fetch *all* completed IDs for this session first
            completedQuestions = databaseManager.getCompletedQuestionIds(sessionId: sessionId)
            print("VM: Session \(sessionId): Total completed IDs fetched = \(completedQuestions.count)")
            // Recalculate the displayed completed count based on the *current* filter
            recalculateCompletedCountForFilter()
        } else {
            completedCount = 0
            completedQuestions = []
            print("VM: No valid session (\(sessionId)), setting completed counts to 0.")
        }
        
        // Initial load for the current filter
        loadRandomQuestion()
    }
    
    // Recalculate completedCount based on current filter
    private func recalculateCompletedCountForFilter() {
        guard sessionId > 0 else {
            completedCount = 0
            return
        }
        
        let currentPotentialIds = getPotentialIdsForCurrentFilter()
        
        if let potentialIds = currentPotentialIds {
            // Filter is active (include/exclude favorites)
            let completedMatchingFilter = Set(completedQuestions).intersection(potentialIds)
            completedCount = completedMatchingFilter.count
            print("VM: Recalculated completedCount (Filtered: \(favoritesFilterState)): \(completedCount) (Intersection of \(completedQuestions.count) session completed and \(potentialIds.count) potential)")
        } else {
            // No specific filter, count all non-hidden completed
            let hiddenIds = Set(databaseManager.getHiddenQuestionIds())
            let completedNonHidden = Set(completedQuestions).subtracting(hiddenIds)
            completedCount = completedNonHidden.count
            print("VM: Recalculated completedCount (No Filter): \(completedCount) (Session completed minus hidden)")
        }
        objectWillChange.send() // Ensure counter UI updates
    }
    
    // Helper to get the set of potential IDs based on the current filter state
    private func getPotentialIdsForCurrentFilter() -> Set<Int>? {
        switch favoritesFilterState {
        case .include:
            return Set(databaseManager.getFavoriteQuestionIds())
        case .exclude:
            // Need all non-hidden IDs first
            let allNonHiddenIds = Set(1...allQuestionsCount).subtracting(Set(databaseManager.getHiddenQuestionIds()))
            let favoriteIds = Set(databaseManager.getFavoriteQuestionIds())
            return allNonHiddenIds.subtracting(favoriteIds)
        case .none:
            return nil // Indicates no filtering based on favorites
        }
    }
    
    // Calculate the total count based on current filters
    private func calculateFilteredTotal() -> Int {
        // Start with total non-hidden questions
        var currentTotal = allQuestionsCount - hiddenQuestionsCount
        
        // Apply favorites filter
        switch favoritesFilterState {
        case .include:
            currentTotal = databaseManager.getFavoriteQuestionCount()
        case .exclude:
            currentTotal -= databaseManager.getFavoriteQuestionCount()
        case .none:
            break // No change needed
        }
        
        // Make sure total isn't negative
        return max(0, currentTotal)
    }
    
    // Cycle through filter states: none -> include -> exclude -> none
    func cycleFavoritesFilter() {
        switch favoritesFilterState {
        case .none:
            favoritesFilterState = .include
        case .include:
            favoritesFilterState = .exclude
        case .exclude:
            favoritesFilterState = .none
        }
        print("VM: Cycled favorites filter state to \(favoritesFilterState)")
        // Reload counts and question based on new filter
        recalculateCompletedCountForFilter() // Recalculate completed count for the new filter
        loadRandomQuestion()
        objectWillChange.send() // Ensure UI updates for progressText
    }
    
    // Mark current question as completed
    func markCurrentQuestionCompleted() {
        guard let question = currentQuestion, sessionId > 0 else { return }
        
        // Mark as completed in the database
        if databaseManager.markQuestionCompleted(sessionId: sessionId, questionId: question.id) {
            // Add to our completed list if not already there
            if !completedQuestions.contains(question.id) {
                completedQuestions.append(question.id)
                // Only increment the displayed count if the completed question matches the current filter
                let currentPotentialIds = getPotentialIdsForCurrentFilter()
                if currentPotentialIds == nil || currentPotentialIds!.contains(question.id) {
                    completedCount += 1
                }
                objectWillChange.send()
            }
        }
    }
    
    // Skip current question (not marking as completed)
    func skipCurrentQuestion() {
        loadRandomQuestion()
    }
    
    // Function needed for ContentView binding
    func fetchRandomQuestion() {
        loadRandomQuestion()
    }
    
    // Load a random question from the database, considering filters
    func loadRandomQuestion() {
        // Get universally excluded IDs (hidden questions)
        let hiddenIds = databaseManager.getHiddenQuestionIds()
        // Get session completed IDs
        let sessionCompletedIds = sessionId > 0 ? completedQuestions : []
        // Combine universal and session exclusions
        var excludeIds = Set(hiddenIds + sessionCompletedIds)
        
        // Determine which set of IDs to *potentially* draw from based on favorite filter
        let potentialIds = getPotentialIdsForCurrentFilter()
        
        print("VM: Loading random question. Filter: \(favoritesFilterState). Exclude count: \(excludeIds.count). Potential count: \(potentialIds?.count ?? -1)")

        // Try to get a random question from the database
        if let question = self.databaseManager.getRandomQuestion(potentialIds: potentialIds, excludeIds: excludeIds) {
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
        // Ensure hidden status is turned off if favoriting
        if preference.isFavorite {
            if preference.isHidden {
                preference.isHidden = false
                // Update total count if it was previously hidden
                hiddenQuestionsCount -= 1
                totalQuestions = allQuestionsCount - hiddenQuestionsCount
            }
        }
        self.questionPreference = preference
        
        // Force UI update - Database save will happen on swipe confirmation
        objectWillChange.send()
    }
    
    // Toggle hidden status
    func toggleHidden() {
        guard let question = currentQuestion, var preference = questionPreference else {
            return
        }
        
        let wasHidden = preference.isHidden
        preference.isHidden.toggle()
        
        // Ensure favorite status is turned off if hiding
        if preference.isHidden {
            preference.isFavorite = false
        }
        self.questionPreference = preference
        
        // Update counts based on hide/unhide
        if preference.isHidden && !wasHidden {
            hiddenQuestionsCount += 1
        } else if !preference.isHidden && wasHidden {
            hiddenQuestionsCount -= 1
        }
        totalQuestions = allQuestionsCount - hiddenQuestionsCount
        
        // Force UI update - Database save and next question load will happen on swipe confirmation
        objectWillChange.send()
    }
} 