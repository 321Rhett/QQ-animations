import SwiftUI
import UIKit
import Combine

// UIKit TextField wrapper that auto-focuses
struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.backgroundColor = UIColor.systemGray6
        textField.returnKeyType = .done
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        
        // Ensure the text field gets focus when it appears - moved to updateUIView
        if !context.coordinator.didBecomeFirstResponder {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                uiView.becomeFirstResponder()
            }
            context.coordinator.didBecomeFirstResponder = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutoFocusTextField
        var didBecomeFirstResponder = false
        
        init(_ parent: AutoFocusTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
            
            // Limit the text length
            if let text = textField.text, text.count > 20 {
                parent.text = String(text.prefix(20))
                textField.text = parent.text
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onCommit()
            return true
        }
    }
}

// Custom alert view for session creation with character limit
struct SessionNameAlert: View {
    @Binding var isPresented: Bool
    @Binding var sessionName: String
    let maxLength: Int
    let onCancel: () -> Void
    let onCreate: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Allow dismissing by tapping outside
                    isPresented = false
                    onCancel()
                }
            
            VStack(spacing: 20) {
                Text("New Session")
                    .font(.headline)
                    .padding(.top)
                
                Text("Enter a name for the new session")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Custom text field with character limit
                VStack(alignment: .leading) {
                    AutoFocusTextField(
                        text: $sessionName,
                        placeholder: "Session Name",
                        onCommit: {
                            if !sessionName.isEmpty {
                                isPresented = false
                                onCreate()
                            }
                        }
                    )
                    .frame(height: 40)
                    .onChange(of: sessionName) { newValue in
                        // Only allow typing up to max characters
                        if newValue.count > maxLength {
                            sessionName = String(newValue.prefix(maxLength))
                        }
                    }
                    
                    // Character counter
                    HStack {
                        Spacer()
                        Text("\(maxLength - sessionName.count) characters remaining")
                            .font(.caption)
                            .foregroundColor(
                                maxLength - sessionName.count <= 5 ? .red : .gray
                            )
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Button("Cancel") {
                        isPresented = false
                        onCancel()
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button("Create") {
                        isPresented = false
                        onCreate()
                    }
                    .disabled(sessionName.isEmpty)
                    .padding()
                    .foregroundColor(sessionName.isEmpty ? .gray : .blue)
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(.horizontal, 50)
        }
    }
}

struct SessionsView: View {
    // ViewModel for database operations
    @StateObject private var viewModel = SessionsViewModel()
    
    // State for creating a new session
    @State private var showingNewSessionAlert = false
    @State private var showingCustomAlert = false
    @State private var showingSessionExistsAlert = false
    @State private var newSessionName = ""
    @State private var showingNameTooLongAlert = false
    @State private var navigateToContentView = false
    @State private var navigatingSession: Session? = nil
    
    // Constants
    private let maxSessionNameLength = 20
    private let buttonFont = Font.system(size: 22, weight: .light, design: .monospaced)
    
    // Get the safe area insets directly from UIKit
    private var safeAreaTop: CGFloat {
        UIApplication.safeAreaInsets.top
    }
    
    private var safeAreaBottom: CGFloat {
        UIApplication.safeAreaInsets.bottom
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer(minLength: 20)
                    
                    // New Session button (golden)
                    Button(action: {
                        // Show custom alert to create a new session
                        newSessionName = "" // Reset name
                        showingCustomAlert = true
                    }) {
                        Text("New Session")
                            .font(buttonFont)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.favoriteSymbol) // Gold color
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .padding(.horizontal, 50)
                    .padding(.bottom, 15)
                    .alert("Session Already Exists", isPresented: $showingSessionExistsAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("A session with this name already exists. Please choose a different name.")
                    }
                    
                    // Existing session buttons
                    if !viewModel.sessions.isEmpty {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Display sessions from the database
                                ForEach(viewModel.sessions) { session in
                                    SessionButtonWithOptions(
                                        session: session,
                                        onContinue: {
                                            // Continue to session (current default behavior)
                                            navigatingSession = session
                                            navigateToContentView = true
                                        },
                                        onViewCompleted: {
                                            // View completed - to be implemented
                                            print("View completed for session: \(session.name)")
                                        },
                                        onViewNotes: {
                                            // View notes - to be implemented
                                            print("View notes for session: \(session.name)")
                                        },
                                        onDelete: {
                                            // Delete session
                                            _ = viewModel.deleteSession(sessionId: session.id)
                                            print("Deleted session: \(session.name) (\(session.id))")
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 50)
                        }
                    } else {
                        // If no sessions, add spacer to maintain layout
                        Spacer()
                    }
                    
                    Spacer(minLength: 10)
                }
                .padding(.top, safeAreaTop)
                .padding(.bottom, safeAreaBottom)
                
                // Custom session name alert
                if showingCustomAlert {
                    SessionNameAlert(
                        isPresented: $showingCustomAlert,
                        sessionName: $newSessionName,
                        maxLength: maxSessionNameLength,
                        onCancel: {
                            newSessionName = ""
                        },
                        onCreate: {
                            if !newSessionName.isEmpty {
                                createNewSession()
                            }
                        }
                    )
                }
            }
            
            // Navigation link to ContentView
            NavigationLink(destination: navigatingSession != nil ? ContentView(session: navigatingSession) : nil, isActive: $navigateToContentView) {
                EmptyView()
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .twoFingerSwipeToDismiss(
            dismissThreshold: 100,  // Swipe 100 points to trigger dismissal
            feedbackThreshold: 50   // Show feedback at 50 points
        )
        .onAppear {
            // Refresh sessions when view appears
            print("SessionsView appeared - refreshing sessions")
            viewModel.loadSessions()
            
            // Reset navigation and session state
            navigateToContentView = false
            navigatingSession = nil
            
            // Debug available sessions
            print("Available sessions: \(viewModel.sessions.count)")
            for session in viewModel.sessions {
                print("Session: ID \(session.id), name: '\(session.name)'")
            }
        }
        .onChange(of: viewModel.sessionExists) { exists in
            print("sessionExists changed to: \(exists)")
            if exists {
                showingSessionExistsAlert = true
            }
        }
        .onChange(of: viewModel.createdSession) { session in
            print("createdSession changed to: \(String(describing: session))")
            if session != nil {
                // Store the session we're navigating to
                navigatingSession = session
                // Navigate to ContentView with the new session
                print("Setting navigateToContentView to true")
                DispatchQueue.main.async {
                    navigateToContentView = true
                }
            }
        }
        .onChange(of: navigateToContentView) { navigate in
            print("navigateToContentView changed to: \(navigate)")
        }
    }
    
    private func createNewSession() {
        print("createNewSession called")
        
        // Trim whitespace and ensure the name isn't too long
        let trimmedName = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.count > maxSessionNameLength {
            newSessionName = String(trimmedName.prefix(maxSessionNameLength))
        } else {
            newSessionName = trimmedName
        }
        
        // Make sure name isn't empty after trimming
        if newSessionName.isEmpty {
            print("Cannot create session with empty name")
            return
        }
        
        print("Creating session with name: '\(newSessionName)' (length: \(newSessionName.count))")
        let success = viewModel.createSession(name: newSessionName)
        print("Session creation success: \(success)")
        newSessionName = ""
        
        // If successful, directly set the navigation
        if success && viewModel.createdSession != nil {
            print("Manually setting navigation")
            navigatingSession = viewModel.createdSession
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToContentView = true
            }
        }
    }
}

// Session button component
struct SessionButton: View {
    let name: String
    private let buttonFont = Font.system(size: 22, weight: .light, design: .monospaced) // Reduced font size from 28 to 22
    
    var body: some View {
        // Clean the name by trimming whitespace and ensuring it's not empty
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Text(displayName.isEmpty ? "Unnamed Session" : displayName)
            .font(buttonFont)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .lineLimit(1)  // Ensure text stays on a single line
            .truncationMode(.tail)  // Add ellipsis if text is too long
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.22, green: 0.22, blue: 0.22)) // Dark gray button background
            )
            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
    }
}

// Session button with options component
struct SessionButtonWithOptions: View {
    let session: Session
    let onContinue: () -> Void
    let onViewCompleted: () -> Void
    let onViewNotes: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    private let buttonFont = Font.system(size: 22, weight: .light, design: .monospaced)
    
    var body: some View {
        VStack {
            SessionButton(name: session.name)
                .contentShape(Rectangle()) // Make entire area tappable
                .onTapGesture {
                    // Default action is continue session
                    onContinue()
                }
                .contextMenu {
                    Button(action: onContinue) {
                        Label("Continue Session", systemImage: "arrow.right")
                    }
                    
                    Button(action: onViewCompleted) {
                        Label("View Completed", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: onViewNotes) {
                        Label("View Notes", systemImage: "note.text")
                    }
                    
                    Button(action: {
                        // We need to use a small delay to let the context menu dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingDeleteConfirmation = true
                        }
                    }) {
                        Label("Delete Session", systemImage: "trash")
                    }
                }
                .alert("Delete Session", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive, action: onDelete)
                } message: {
                    Text("Are you sure you want to delete this session? This action cannot be undone.")
                }
        }
    }
}

#Preview {
    NavigationView {
        SessionsView()
    }
} 