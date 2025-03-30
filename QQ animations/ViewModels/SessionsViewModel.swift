import Foundation
import SwiftUI

class SessionsViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    private let databaseManager = DatabaseManager.shared
    
    init() {
        // Initialize the sessions table
        _ = databaseManager.initializeSessionsTable()
        // Load sessions from database
        loadSessions()
    }
    
    // Load all sessions from the database
    func loadSessions() {
        sessions = databaseManager.getAllSessions()
    }
    
    // Create a new session
    func createSession(name: String) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        if let newSession = databaseManager.createSession(name: name) {
            // Refresh sessions list
            loadSessions()
            return true
        }
        
        return false
    }
    
    // Delete a session
    func deleteSession(sessionId: Int) -> Bool {
        let success = databaseManager.deleteSession(sessionId: sessionId)
        if success {
            // Refresh sessions list
            loadSessions()
        }
        return success
    }
} 