import Foundation
import SwiftUI

class NotesViewModel: ObservableObject {
    @Published var currentNote: Note?
    @Published var noteContent: String = ""
    @Published var characterCount: Int = 0
    private let maxCharacters = 350
    
    private var sessionId: Int
    private var questionId: Int
    private let databaseManager = DatabaseManager.shared
    
    init(sessionId: Int, questionId: Int) {
        self.sessionId = sessionId
        self.questionId = questionId
        loadNote()
    }
    
    func updateQuestion(sessionId: Int, questionId: Int) {
        self.sessionId = sessionId
        self.questionId = questionId
        loadNote()
    }
    
    private func loadNote() {
        if let note = databaseManager.getNote(sessionId: sessionId, questionId: questionId) {
            currentNote = note
            noteContent = note.content
            characterCount = note.content.count
        } else {
            // Clear the note when switching to a question that doesn't have one
            currentNote = nil
            noteContent = ""
            characterCount = 0
        }
    }
    
    func saveNote() {
        guard !noteContent.isEmpty else { return }
        
        if let existingNote = currentNote {
            if databaseManager.updateNote(noteId: existingNote.id, content: noteContent) {
                currentNote = Note(id: existingNote.id, 
                                 sessionId: sessionId, 
                                 questionId: questionId, 
                                 content: noteContent)
            }
        } else {
            if let newNote = databaseManager.createNote(sessionId: sessionId, 
                                                      questionId: questionId, 
                                                      content: noteContent) {
                currentNote = newNote
            }
        }
    }
    
    func updateNoteContent(_ content: String) {
        if content.count <= maxCharacters {
            noteContent = content
            characterCount = content.count
        }
    }
    
    func clearNoteContent() {
        noteContent = "" // Clear the editor text
        characterCount = 0 // Reset character count
        // We don't delete the actual note, just clear the editor state
        // If the user wants to revert, they can cancel and reopen
    }
    
    var remainingCharacters: Int {
        maxCharacters - characterCount
    }
    
    var isAtCharacterLimit: Bool {
        characterCount >= maxCharacters
    }
} 