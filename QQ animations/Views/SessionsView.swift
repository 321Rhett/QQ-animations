import SwiftUI
import UIKit

struct SessionsView: View {
    // ViewModel for database operations
    @StateObject private var viewModel = SessionsViewModel()
    
    // State for creating a new session
    @State private var showingNewSessionAlert = false
    @State private var newSessionName = ""
    
    // Constants for sizing and positioning
    private let filagreeHeight: CGFloat = 50
    private let topSpacing: CGFloat = 0
    private let bottomSpacing: CGFloat = 0
    
    // Font constants
    private let buttonFont = Font.system(size: 28, weight: .light, design: .monospaced)
    
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
                    // Top filagree container
                    ZStack {
                        Rectangle()
                            .fill(Color.appBackground)
                            .frame(height: filagreeHeight)
                        
                        // Add filagree to top area
                        FilagreeView(color: .filagree, isFlipped: false)
                            .frame(height: filagreeHeight * 0.8)
                            .padding(.horizontal)
                    }
                    .frame(height: filagreeHeight)
                    .padding(.top, safeAreaTop + topSpacing)
                    
                    // Title
                    Text("Sessions")
                        .font(.system(size: 32, weight: .light, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    Spacer(minLength: 20)
                    
                    // New Session button (golden)
                    Button(action: {
                        // Show alert to create a new session
                        showingNewSessionAlert = true
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
                    .alert("New Session", isPresented: $showingNewSessionAlert) {
                        TextField("Session Name", text: $newSessionName)
                        Button("Cancel", role: .cancel) {
                            newSessionName = ""
                        }
                        Button("Create") {
                            if !newSessionName.isEmpty {
                                _ = viewModel.createSession(name: newSessionName)
                                newSessionName = ""
                            }
                        }
                    } message: {
                        Text("Enter a name for the new session")
                    }
                    
                    // Existing session buttons
                    if !viewModel.sessions.isEmpty {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Display sessions from the database
                                ForEach(viewModel.sessions) { session in
                                    SessionButton(name: session.name)
                                }
                            }
                            .padding(.horizontal, 50)
                        }
                    } else {
                        // If no sessions, add spacer to maintain layout
                        Spacer()
                    }
                    
                    // Bottom filagree container
                    ZStack {
                        Rectangle()
                            .fill(Color.appBackground)
                            .frame(height: filagreeHeight)
                        
                        // Add filagree to bottom area, flipped vertically
                        FilagreeView(color: .filagree, isFlipped: true)
                            .frame(height: filagreeHeight * 0.8)
                            .padding(.horizontal)
                    }
                    .frame(height: filagreeHeight)
                    .padding(.bottom, safeAreaBottom + bottomSpacing)
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            // Refresh sessions when view appears
            viewModel.loadSessions()
        }
    }
}

// Session button component
struct SessionButton: View {
    let name: String
    private let buttonFont = Font.system(size: 28, weight: .light, design: .monospaced)
    
    var body: some View {
        Button(action: {
            // Action for selecting this session
        }) {
            Text(name)
                .font(buttonFont)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.22, green: 0.22, blue: 0.22)) // Dark gray button background
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
}

#Preview {
    NavigationView {
        SessionsView()
    }
} 