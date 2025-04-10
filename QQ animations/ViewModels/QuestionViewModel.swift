import Foundation
import SwiftUI

class QuestionViewModel: ObservableObject {
    @Published var currentQuestion: Question?
    @Published var questionPreference: UserPreference?
    @Published var completedQuestions: [Int] = []
    @Published var totalQuestions: Int = 0
    @Published var completedCount: Int = 0
    @Published var favoritesFilterState: FilterState = .none
    @Published var tagFilterStates: [String: FilterState] = [:]
    
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
        // Initialize tag filter states before loading counts
        initializeTagFilters()
        loadQuestionCounts()
    }
    
    // Initialize tag filters dictionary
    private func initializeTagFilters() {
        let allTags = databaseManager.getAllTags()

        // Try direct dictionary initialization from map
        let initialStates = Dictionary(uniqueKeysWithValues: allTags.map { ($0, FilterState.none) })
        
        // Assign to the @Published property
        self.tagFilterStates = initialStates 

        // Check keys immediately after assignment

        // Check again after a tiny delay - shouldn't be necessary in init, but for debugging
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        }
    }
    
    // Load initial question counts
    private func loadQuestionCounts() {
        allQuestionsCount = databaseManager.getQuestionCount()
        hiddenQuestionsCount = databaseManager.getHiddenQuestionCount()
        
        // Calculate the total *initially* available questions (total - hidden)
        // Filtered total will be calculated separately
        totalQuestions = allQuestionsCount - hiddenQuestionsCount
        
        // If we have a valid session, get completed questions
        if sessionId > 0 {
            // Fetch *all* completed IDs for this session first
            completedQuestions = databaseManager.getCompletedQuestionIds(sessionId: sessionId)
            // Recalculate the displayed completed count based on the *current* filter
            recalculateCompletedCountForFilter()
        } else {
            completedCount = 0
            completedQuestions = []
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
        } else {
            // No specific filter, count all non-hidden completed
            let hiddenIds = Set(databaseManager.getHiddenQuestionIds())
            let completedNonHidden = Set(completedQuestions).subtracting(hiddenIds)
            completedCount = completedNonHidden.count
        }
        objectWillChange.send() // Ensure counter UI updates
    }
    
    // Helper to get the set of potential IDs based on the current filter state
    private func getPotentialIdsForCurrentFilter() -> Set<Int>? {
        // Start with all non-hidden IDs
        let allNonHiddenIds = Set(1...allQuestionsCount).subtracting(Set(databaseManager.getHiddenQuestionIds()))
        var currentPotentialIds = allNonHiddenIds

        // Apply favorites filter
        switch favoritesFilterState {
        case .include:
            currentPotentialIds = currentPotentialIds.intersection(Set(databaseManager.getFavoriteQuestionIds()))
        case .exclude:
            currentPotentialIds = currentPotentialIds.subtracting(Set(databaseManager.getFavoriteQuestionIds()))
        case .none:
            break // No change needed
        }
        
        // Apply tag filters
        let includedTags = tagFilterStates.filter { $0.value == .include }.map { $0.key }
        let excludedTags = tagFilterStates.filter { $0.value == .exclude }.map { $0.key }
        
        if !includedTags.isEmpty {
            // Get IDs that have *at least one* of the included tags
            let includedIds = Set(databaseManager.getQuestionIds(matchingTags: includedTags, condition: .any))
            currentPotentialIds = currentPotentialIds.intersection(includedIds)
        }
        
        if !excludedTags.isEmpty {
            // Get IDs that have *any* of the excluded tags and subtract them
            let excludedIds = Set(databaseManager.getQuestionIds(matchingTags: excludedTags, condition: .any))
            currentPotentialIds = currentPotentialIds.subtracting(excludedIds)
        }

        // If no filters actively changed the set, return nil (meaning use all non-hidden)
        // Otherwise, return the final filtered set.
        // Correction: We should always return the calculated set unless it's identical to allNonHiddenIds AND no filters were active.
        // Let's simplify: return the calculated set. If it's empty due to filters, getRandomQuestion handles it.
        return currentPotentialIds
    }
    
    // Calculate the total count based on current filters
    private func calculateFilteredTotal() -> Int {
        // Use the same logic as potential IDs to get the count
        let potentialIds = getPotentialIdsForCurrentFilter()
        let count = potentialIds?.count ?? (allQuestionsCount - hiddenQuestionsCount)
        // Make sure total isn't negative
        return max(0, count)
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
        // Reload counts and question based on new filter
        recalculateCompletedCountForFilter() // Recalculate completed count for the new filter
        loadRandomQuestion()
        objectWillChange.send() // Ensure UI updates for progressText
    }
    
    // Cycle through tag filter states
    func cycleTagFilter(tag: String) {
        guard let currentState = tagFilterStates[tag] else { // Use optional binding
            return
        }
        
        let nextState: FilterState
        switch currentState {
        case .none:
            nextState = .include
        case .include:
            nextState = .exclude
        case .exclude:
            nextState = .none // Correctly cycle back to .none
        }
        tagFilterStates[tag] = nextState // Assign the calculated next state

        // Reload counts and question based on new filter
        recalculateCompletedCountForFilter()
        loadRandomQuestion()
        objectWillChange.send()
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
        let excludeIds = Set(hiddenIds + sessionCompletedIds)
        
        // Determine which set of IDs to *potentially* draw from based on current filters
        let potentialIds = getPotentialIdsForCurrentFilter()
        
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
        guard let _ = currentQuestion, var preference = questionPreference else {
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
        guard let _ = currentQuestion, var preference = questionPreference else {
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