import Foundation
import SwiftUI

class SessionsViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var sessionExists: Bool = false
    @Published var createdSession: Session? = nil
    
    private let databaseManager = DatabaseManager.shared
    
    init() {
        print("Initializing SessionsViewModel")
        // Initialize the sessions table with proper schema
        let success = databaseManager.initializeSessionsTable()
        print("Sessions table initialization: \(success ? "successful" : "failed")")
        // Load sessions from database
        loadSessions()
    }
    
    // Load all sessions from the database
    func loadSessions() {
        sessions = databaseManager.getAllSessions()
    }
    
    // Create a new session
    func createSession(name: String) -> Bool {
        print("Creating session with name: \(name)")
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Session name is empty")
            return false
        }
        
        // Reset state
        sessionExists = false
        createdSession = nil
        
        // Check if session already exists
        if databaseManager.sessionExists(name: name) {
            print("Session exists: \(name)")
            sessionExists = true
            return false
        }
        
        if let newSession = databaseManager.createSession(name: name) {
            print("Created new session: \(newSession.name) with id: \(newSession.id)")
            // Store created session (important to do this before refreshing sessions)
            createdSession = newSession
            // Refresh sessions list
            loadSessions()
            
            // Ensure createdSession is still set after loading sessions
            DispatchQueue.main.async {
                print("Ensuring createdSession is still set: \(String(describing: self.createdSession))")
                self.objectWillChange.send() // Explicitly notify observers
            }
            
            print("createdSession set to: \(String(describing: createdSession))")
            return true
        }
        
        print("Failed to create session")
        return false
    }
    
    // Delete a session
    func deleteSession(sessionId: Int) -> Bool {
        print("Attempting to delete session with ID: \(sessionId)")
        let success = databaseManager.deleteSession(sessionId: sessionId)
        if success {
            print("Successfully deleted session with ID: \(sessionId)")
            // Refresh sessions list
            loadSessions()
        } else {
            print("Failed to delete session with ID: \(sessionId)")
        }
        return success
    }
} 