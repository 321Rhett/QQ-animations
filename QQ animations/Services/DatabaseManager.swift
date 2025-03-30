import Foundation
import SQLite3

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
        print("Sessions table initialized successfully")
        return true
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
        
        let dateFormatter = ISO8601DateFormatter()
        let currentDate = dateFormatter.string(from: Date())
        
        let insertQuery = "INSERT INTO sessions (name, creation_date) VALUES (?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing insert statement: \(error)")
            return nil
        }
        
        sqlite3_bind_text(statement, 1, name.cString(using: .utf8), -1, nil)
        sqlite3_bind_text(statement, 2, currentDate.cString(using: .utf8), -1, nil)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error inserting session: \(error)")
            sqlite3_finalize(statement)
            return nil
        }
        
        // Get the ID of the last inserted row
        let sessionId = Int(sqlite3_last_insert_rowid(db))
        
        sqlite3_finalize(statement)
        
        return Session(id: sessionId, name: name)
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
        let query = "SELECT session_id, name, creation_date FROM sessions ORDER BY creation_date DESC;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing query: \(error)")
            return []
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int(statement, 0)
            
            guard let nameCString = sqlite3_column_text(statement, 1) else {
                continue
            }
            let name = String(cString: nameCString)
            
            var creationDate = Date()
            if let dateCString = sqlite3_column_text(statement, 2) {
                let dateString = String(cString: dateCString)
                if let date = dateFormatter.date(from: dateString) {
                    creationDate = date
                }
            }
            
            let session = Session(id: Int(id), name: name, creationDate: creationDate)
            sessions.append(session)
        }
        
        sqlite3_finalize(statement)
        return sessions
    }
    
    // Function to delete a session by ID
    func deleteSession(sessionId: Int) -> Bool {
        guard isInitialized, let db = userDB else {
            print("Database not initialized")
            return false
        }
        
        let deleteQuery = "DELETE FROM sessions WHERE session_id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error preparing delete statement: \(error)")
            return false
        }
        
        sqlite3_bind_int(statement, 1, Int32(sessionId))
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error deleting session: \(error)")
            sqlite3_finalize(statement)
            return false
        }
        
        sqlite3_finalize(statement)
        return true
    }
} 