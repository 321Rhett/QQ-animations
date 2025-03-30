import Foundation
import SQLite3

// SQLite constants
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var masterDB: OpaquePointer?
    private var userDB: OpaquePointer?
    private var isInitialized = false
    
    private init() {
        print("Initializing DatabaseManager")
        
        // Debug: Print the contents of the main bundle
        listBundleContents()
        
        // Initialize master database - try different paths to locate the database
        var masterDBPath: String?
        // Try without directory first
        if let path = Bundle.main.path(forResource: "master_questions", ofType: "db") {
            masterDBPath = path
        } 
        // Try with Resources directory
        else if let path = Bundle.main.path(forResource: "Resources/Databases/master_questions", ofType: "db") {
            masterDBPath = path
        }
        // Try with just Databases directory
        else if let path = Bundle.main.path(forResource: "Databases/master_questions", ofType: "db") {
            masterDBPath = path
        }
        
        guard let finalMasterPath = masterDBPath else {
            print("Error: Master database file not found in bundle")
            print("Bundle paths checked: \(Bundle.main.bundlePath)")
            return
        }
        
        print("Found master database at: \(finalMasterPath)")
        
        if sqlite3_open(finalMasterPath, &masterDB) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(masterDB))
            print("Error opening master database: \(error)")
            return
        }
        print("Master database opened successfully")
        
        // Initialize user database - try different paths to locate the database
        var userDBPath: String?
        
        // For user database, we need to copy it to Documents directory
        // to make it writable, but first find it in the bundle
        var bundleUserDBPath: String?
        
        // Try without directory first
        if let path = Bundle.main.path(forResource: "user_data", ofType: "db") {
            bundleUserDBPath = path
        } 
        // Try with Resources directory
        else if let path = Bundle.main.path(forResource: "Resources/Databases/user_data", ofType: "db") {
            bundleUserDBPath = path
        }
        // Try with just Databases directory
        else if let path = Bundle.main.path(forResource: "Databases/user_data", ofType: "db") {
            bundleUserDBPath = path
        }
        
        // Check if we found the bundled database
        if let bundlePath = bundleUserDBPath {
            // Get Documents directory path
            let fileManager = FileManager.default
            let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationUrl = documentsUrl.appendingPathComponent("user_data.db")
            userDBPath = destinationUrl.path
            
            print("Bundle user database: \(bundlePath)")
            print("Documents user database: \(userDBPath!)")
            
            // Check if file already exists in Documents
            if !fileManager.fileExists(atPath: userDBPath!) {
                do {
                    // Copy the database to Documents (only on first run)
                    try fileManager.copyItem(atPath: bundlePath, toPath: userDBPath!)
                    print("Copied user database to Documents directory")
                } catch {
                    print("Error copying user database: \(error)")
                }
            } else {
                print("User database already exists in Documents directory")
            }
        } else {
            print("Error: User database file not found in bundle")
            print("Bundle paths checked: \(Bundle.main.bundlePath)")
            return
        }
        
        if sqlite3_open(userDBPath!, &userDB) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(userDB))
            print("Error opening user database: \(error)")
            return
        }
        print("User database opened successfully")
        
        isInitialized = true
    }
    
    deinit {
        sqlite3_close(masterDB)
        sqlite3_close(userDB)
    }
    
    // Helper to list contents of main bundle for debugging
    private func listBundleContents() {
        print("\n--- Bundle Contents ---")
        let fileManager = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        
        do {
            let items = try fileManager.contentsOfDirectory(atPath: bundlePath)
            print("Items in bundle root: \(items)")
            
            // Check for Resources directory
            if items.contains("Resources") {
                let resourcesPath = bundlePath + "/Resources"
                let resourcesItems = try fileManager.contentsOfDirectory(atPath: resourcesPath)
                print("Items in Resources: \(resourcesItems)")
                
                // Check for Databases directory
                if resourcesItems.contains("Databases") {
                    let databasesPath = resourcesPath + "/Databases"
                    let databasesItems = try fileManager.contentsOfDirectory(atPath: databasesPath)
                    print("Items in Databases: \(databasesItems)")
                }
            }
        } catch {
            print("Error listing bundle contents: \(error)")
        }
        print("--- End Bundle Contents ---\n")
    }
    
    // Basic function to test if we can read from the database
    func getRandomQuestion() -> Question? {
        guard isInitialized, let db = masterDB else {
            print("Database not initialized")
            return nil
        }
        
        let queryString = "SELECT question_id, question_text, pack, version_added, tags FROM questions ORDER BY RANDOM() LIMIT 1;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int(statement, 0)
                
                let questionText = sqlite3_column_text(statement, 1)
                let text = questionText != nil ? String(cString: questionText!) : "No question text"
                
                let packCString = sqlite3_column_text(statement, 2)
                let pack = packCString != nil ? String(cString: packCString!) : "unknown"
                
                let versionAdded = sqlite3_column_text(statement, 3)
                let version = versionAdded != nil ? String(cString: versionAdded!) : "0.0"
                
                let tagsCString = sqlite3_column_text(statement, 4)
                let tags = tagsCString != nil ? String(cString: tagsCString!) : ""
                
                sqlite3_finalize(statement)
                return Question(id: Int(id), questionText: text, pack: pack, versionAdded: version, tags: tags)
            }
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    // Function to update user preferences for a question
    func updateQuestionPreference(questionId: Int, isFavorite: Bool, isHidden: Bool) -> Bool {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return false
        }
        
        // First delete any existing preference
        let deleteQuery = "DELETE FROM user_preferences WHERE question_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing delete statement: \(error)")
            return false
        }
        
        sqlite3_bind_int(statement, 1, Int32(questionId))
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error deleting preferences: \(error)")
            sqlite3_finalize(statement)
            return false
        }
        
        sqlite3_finalize(statement)
        
        // If both are false, just return as we've already deleted any preference
        if !isFavorite && !isHidden {
            return true
        }
        
        // Insert the new preference
        // We'll prioritize favorite over hidden if both are true
        let status = isFavorite ? "favorite" : "hidden"
        let insertQuery = "INSERT INTO user_preferences (question_id, status) VALUES (?, ?);"
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing insert statement: \(error)")
            return false
        }
        
        sqlite3_bind_int(statement, 1, Int32(questionId))
        sqlite3_bind_text(statement, 2, status.cString(using: .utf8), -1, nil)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error inserting preference: \(error)")
            sqlite3_finalize(statement)
            return false
        }
        
        sqlite3_finalize(statement)
        return true
    }
    
    // Function to get user preferences for a question
    func getQuestionPreference(questionId: Int) -> UserPreference? {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return nil
        }
        
        let query = "SELECT question_id, status FROM user_preferences WHERE question_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing query: \(error)")
            return nil
        }
        
        sqlite3_bind_int(statement, 1, Int32(questionId))
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int(statement, 0)
            
            let statusCString = sqlite3_column_text(statement, 1)
            let status = statusCString != nil ? String(cString: statusCString!) : ""
            
            let isFavorite = status == "favorite"
            let isHidden = status == "hidden"
            
            sqlite3_finalize(statement)
            return UserPreference(questionId: Int(id), isFavorite: isFavorite, isHidden: isHidden)
        }
        
        sqlite3_finalize(statement)
        // Return default preferences if none found
        return UserPreference(questionId: questionId)
    }
    
    // Function to ensure the sessions table exists in the user database
    func initializeSessionsTable() -> Bool {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return false
        }
        
        // First check if the table has the correct schema
        let checkQuery = "PRAGMA table_info(sessions);"
        var checkStatement: OpaquePointer?
        var _ = false  // Changed hasCorrectSchema to _ since it's not used
        var nameColumnExists = false
        
        if sqlite3_prepare_v2(db, checkQuery, -1, &checkStatement, nil) == SQLITE_OK {
            // Check if the 'name' column exists
            while sqlite3_step(checkStatement) == SQLITE_ROW {
                if let columnNameCString = sqlite3_column_text(checkStatement, 1) {
                    let columnName = String(cString: columnNameCString)
                    print("Found column: \(columnName)")
                    if columnName == "name" {
                        nameColumnExists = true
                    }
                }
            }
        }
        sqlite3_finalize(checkStatement)
        
        // If 'name' column doesn't exist, drop and recreate the table
        if !nameColumnExists {
            print("Sessions table has incorrect schema, recreating...")
            
            // Drop the existing table
            let dropQuery = "DROP TABLE IF EXISTS sessions;"
            var dropStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropQuery, -1, &dropStatement, nil) == SQLITE_OK {
                if sqlite3_step(dropStatement) == SQLITE_DONE {
                    print("Successfully dropped sessions table")
                } else {
                    let error = String(cString: sqlite3_errmsg(db))
                    print("Error dropping sessions table: \(error)")
                }
            }
            sqlite3_finalize(dropStatement)
        } else {
            print("Sessions table has correct schema")
            
            // Fix any corrupted session names
            fixCorruptedSessionNames()
            
            return true
        }
        
        let createTableQuery = """
            CREATE TABLE IF NOT EXISTS sessions (
                session_id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                creation_date TEXT NOT NULL
            );
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing create table statement: \(error)")
            return false
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error creating sessions table: \(error)")
            sqlite3_finalize(statement)
            return false
        }
        
        sqlite3_finalize(statement)
        print("Sessions table initialized successfully with correct schema")
        return true
    }
    
    // Function to fix corrupted session names
    private func fixCorruptedSessionNames() {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return
        }
        
        print("Checking for corrupted session names...")
        
        // Get all sessions
        let query = "SELECT session_id, name FROM sessions;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing query: \(error)")
            return
        }
        
        var corruptedSessions = [(Int32, String)]()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int(statement, 0)
            
            // Check name
            var name = ""
            var needsFixing = false
            
            if sqlite3_column_type(statement, 1) == SQLITE_TEXT {
                if let namePtr = sqlite3_column_text(statement, 1) {
                    name = String(cString: namePtr)
                    
                    // Check if name is empty
                    if name.isEmpty {
                        needsFixing = true
                    } else {
                        // Check for invalid characters only
                        for char in name {
                            // Only check for truly invalid characters
                            if !char.isASCII || 
                               !(char.isLetter || char.isNumber || char.isPunctuation || char.isWhitespace) {
                                print("Corrupted character found in name: '\(char)' (Unicode: \(char.unicodeScalars.first?.value ?? 0))")
                                needsFixing = true
                                break
                            }
                        }
                    }
                    
                    // Print the name for debugging
                    print("Session ID \(id) has name '\(name)' (length: \(name.count)) - needs fixing: \(needsFixing)")
                } else {
                    needsFixing = true
                }
            } else {
                needsFixing = true
            }
            
            if needsFixing {
                let newName = "Session \(id)"
                corruptedSessions.append((id, newName))
            }
        }
        
        sqlite3_finalize(statement)
        
        // Fix corrupted names
        if !corruptedSessions.isEmpty {
            print("Found \(corruptedSessions.count) corrupted session names to fix")
            
            for (sessionId, newName) in corruptedSessions {
                updateSessionName(sessionId: Int(sessionId), name: newName)
            }
        } else {
            print("No corrupted session names found")
        }
    }
    
    // Function to create a new session in the database
    func createSession(name: String) -> Session? {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return nil
        }
        
        // Make sure the sessions table exists
        if !initializeSessionsTable() {
            return nil
        }
        
        // Ensure the name is trimmed of any whitespace
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            print("Error: Cannot create session with empty name")
            return nil
        }
        
        // Ensure the session name is not too long (limit to 20 characters to match UI limits)
        let finalName = trimmedName.count > 20 ? String(trimmedName.prefix(20)) : trimmedName
        print("Trimmed session name to: '\(finalName)' (length: \(finalName.count))")
        
        let dateFormatter = ISO8601DateFormatter()
        let currentDate = dateFormatter.string(from: Date())
        
        let insertQuery = "INSERT INTO sessions (name, creation_date) VALUES (?, ?);"
        var statement: OpaquePointer?
        
        print("Creating session with name: '\(finalName)' (length: \(finalName.count))")
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing insert statement: \(error)")
            return nil
        }
        
        // Convert to C string directly
        if let nameCString = finalName.cString(using: .utf8) {
            // Bind using SQLITE_TRANSIENT to make sure SQLite makes its own copy
            sqlite3_bind_text(statement, 1, nameCString, -1, SQLITE_TRANSIENT)
        } else {
            print("Error converting name to C string")
            sqlite3_finalize(statement)
            return nil
        }
        
        if let dateCString = currentDate.cString(using: .utf8) {
            sqlite3_bind_text(statement, 2, dateCString, -1, SQLITE_TRANSIENT)
        } else {
            print("Error converting date to C string")
            sqlite3_finalize(statement)
            return nil
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error inserting session: \(error)")
            sqlite3_finalize(statement)
            return nil
        }
        
        // Get the ID of the last inserted row
        let sessionId = Int(sqlite3_last_insert_rowid(db))
        print("Created session with ID: \(sessionId), name: '\(finalName)'")
        
        sqlite3_finalize(statement)
        
        // Directly create the session object with the provided name
        let newSession = Session(id: sessionId, name: finalName)
        print("Returning new session: \(newSession)")
        return newSession
    }
    
    // Function to get all sessions from the database
    func getAllSessions() -> [Session] {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return []
        }
        
        // Make sure the sessions table exists
        if !initializeSessionsTable() {
            return []
        }
        
        var sessions: [Session] = []
        
        // First try to dump the entire table for debugging
        print("DEBUG: Dumping all fields from sessions table")
        let debugQuery = "SELECT * FROM sessions;"
        var debugStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, debugQuery, -1, &debugStatement, nil) == SQLITE_OK {
            // Get column count
            let columnCount = sqlite3_column_count(debugStatement)
            
            // Get column names
            var columnNames: [String] = []
            for i in 0..<columnCount {
                if let namePtr = sqlite3_column_name(debugStatement, i) {
                    columnNames.append(String(cString: namePtr))
                } else {
                    columnNames.append("column_\(i)")
                }
            }
            print("Columns: \(columnNames)")
            
            // Fetch rows
            while sqlite3_step(debugStatement) == SQLITE_ROW {
                var rowData: [String: String] = [:]
                for i in 0..<columnCount {
                    let columnName = columnNames[Int(i)]
                    var value = "NULL"
                    
                    // For text columns, we need to be careful
                    let columnType = sqlite3_column_type(debugStatement, i)
                    
                    if columnType == SQLITE_TEXT {
                        if let textPtr = sqlite3_column_text(debugStatement, i) {
                            value = String(cString: textPtr)
                        }
                    } else if columnType == SQLITE_INTEGER {
                        value = String(sqlite3_column_int(debugStatement, i))
                    }
                    
                    rowData[columnName] = value
                }
                print("Row: \(rowData)")
            }
        }
        sqlite3_finalize(debugStatement)
        
        // Now do the regular query
        let query = "SELECT session_id, name, creation_date FROM sessions ORDER BY creation_date DESC;"
        var statement: OpaquePointer?
        
        print("Fetching all sessions...")
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing query: \(error)")
            return []
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int(statement, 0)
            
            // Get name safely
            var name = ""
            if sqlite3_column_type(statement, 1) == SQLITE_TEXT {
                if let namePtr = sqlite3_column_text(statement, 1) {
                    name = String(cString: namePtr)
                    print("Session \(id) name from DB: '\(name)'")
                }
            } else {
                print("Session \(id) name is not TEXT type")
            }
            
            // If name is empty after retrieval, use a default name
            if name.isEmpty {
                name = "Session \(id)"
                print("Using default name for session: \(name)")
                
                // Update the database with this default name
                updateSessionName(sessionId: Int(id), name: name)
            }
            
            var creationDate = Date()
            if let dateCString = sqlite3_column_text(statement, 2) {
                let dateString = String(cString: dateCString)
                if let date = dateFormatter.date(from: dateString) {
                    creationDate = date
                }
            }
            
            // Create session with the actual name
            let session = Session(id: Int(id), name: name, creationDate: creationDate)
            print("Created session object: ID \(session.id), name: '\(session.name)'")
            sessions.append(session)
        }
        
        sqlite3_finalize(statement)
        print("Returning \(sessions.count) sessions")
        return sessions
    }
    
    // Helper function to update session name
    private func updateSessionName(sessionId: Int, name: String) {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return
        }
        
        let updateQuery = "UPDATE sessions SET name = ? WHERE session_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK {
            if let nameCString = name.cString(using: .utf8) {
                sqlite3_bind_text(statement, 1, nameCString, -1, SQLITE_TRANSIENT)
            } else {
                print("Error converting name to C string")
                sqlite3_finalize(statement)
                return
            }
            
            sqlite3_bind_int(statement, 2, Int32(sessionId))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Updated session \(sessionId) with name '\(name)'")
            } else {
                let error = String(cString: sqlite3_errmsg(db))
                print("Error updating session name: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    // Function to delete a session by ID
    func deleteSession(sessionId: Int) -> Bool {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return false
        }
        
        // Begin transaction
        if sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error beginning transaction: \(error)")
            return false
        }
        
        var success = true
        
        // 1. Delete from sessions table
        let deleteSessionQuery = "DELETE FROM sessions WHERE session_id = ?;"
        var sessionStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSessionQuery, -1, &sessionStatement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing delete session statement: \(error)")
            success = false
        } else {
            sqlite3_bind_int(sessionStatement, 1, Int32(sessionId))
            
            if sqlite3_step(sessionStatement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                print("Error deleting session: \(error)")
                success = false
            } else {
                print("Successfully deleted session with ID: \(sessionId)")
            }
            
            sqlite3_finalize(sessionStatement)
        }
        
        // 2. Delete any session_questions records (if that table exists)
        let checkTableQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='session_questions';"
        var checkTableStatement: OpaquePointer?
        var hasSessionQuestionsTable = false
        
        if sqlite3_prepare_v2(db, checkTableQuery, -1, &checkTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(checkTableStatement) == SQLITE_ROW {
                hasSessionQuestionsTable = true
            }
        }
        sqlite3_finalize(checkTableStatement)
        
        if hasSessionQuestionsTable {
            let deleteQuestionsQuery = "DELETE FROM session_questions WHERE session_id = ?;"
            var questionsStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteQuestionsQuery, -1, &questionsStatement, nil) == SQLITE_OK {
                sqlite3_bind_int(questionsStatement, 1, Int32(sessionId))
                
                if sqlite3_step(questionsStatement) != SQLITE_DONE {
                    let error = String(cString: sqlite3_errmsg(db))
                    print("Error deleting session questions: \(error)")
                    // Don't set success to false here, as this is optional
                } else {
                    print("Deleted related questions for session ID: \(sessionId)")
                }
                
                sqlite3_finalize(questionsStatement)
            }
        }
        
        // 3. Delete any session_notes records (if that table exists)
        let checkNotesTableQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='session_notes';"
        var checkNotesStatement: OpaquePointer?
        var hasSessionNotesTable = false
        
        if sqlite3_prepare_v2(db, checkNotesTableQuery, -1, &checkNotesStatement, nil) == SQLITE_OK {
            if sqlite3_step(checkNotesStatement) == SQLITE_ROW {
                hasSessionNotesTable = true
            }
        }
        sqlite3_finalize(checkNotesStatement)
        
        if hasSessionNotesTable {
            let deleteNotesQuery = "DELETE FROM session_notes WHERE session_id = ?;"
            var notesStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteNotesQuery, -1, &notesStatement, nil) == SQLITE_OK {
                sqlite3_bind_int(notesStatement, 1, Int32(sessionId))
                
                if sqlite3_step(notesStatement) != SQLITE_DONE {
                    let error = String(cString: sqlite3_errmsg(db))
                    print("Error deleting session notes: \(error)")
                    // Don't set success to false here, as this is optional
                } else {
                    print("Deleted related notes for session ID: \(sessionId)")
                }
                
                sqlite3_finalize(notesStatement)
            }
        }
        
        // Commit or rollback transaction based on success
        if success {
            if sqlite3_exec(db, "COMMIT", nil, nil, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                print("Error committing transaction: \(error)")
                success = false
            } else {
                print("Successfully committed all session deletion operations")
            }
        } else {
            if sqlite3_exec(db, "ROLLBACK", nil, nil, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                print("Error rolling back transaction: \(error)")
            } else {
                print("Rolled back session deletion due to errors")
            }
        }
        
        return success
    }
    
    // Function to check if a session with this name already exists
    func sessionExists(name: String) -> Bool {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return false
        }
        
        // Make sure the sessions table exists
        if !initializeSessionsTable() {
            return false
        }
        
        let query = "SELECT count(*) FROM sessions WHERE name = ?;"
        var statement: OpaquePointer?
        
        print("Checking if session exists with name: '\(name)'")
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing query: \(error)")
            return false
        }
        
        // Convert to C string directly
        if let nameCString = name.cString(using: .utf8) {
            // Use SQLITE_TRANSIENT to make sure SQLite makes its own copy
            sqlite3_bind_text(statement, 1, nameCString, -1, SQLITE_TRANSIENT)
        } else {
            print("Error converting name to C string")
            sqlite3_finalize(statement)
            return false
        }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_int(statement, 0)
            sqlite3_finalize(statement)
            print("Found \(count) sessions with name: '\(name)'")
            return count > 0
        }
        
        sqlite3_finalize(statement)
        return false
    }
} 