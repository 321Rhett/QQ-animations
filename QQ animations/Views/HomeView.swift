import SwiftUI
import UIKit

struct HomeView: View {
    // Constants for sizing and positioning
    private let filagreeHeight: CGFloat = 50
    private let topSpacing: CGFloat = 0
    private let bottomSpacing: CGFloat = 0
    
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
                    // Top filagree container - positioned correctly at the top edge
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
                    
                    // Center content with flexible spacing
                    Spacer(minLength: 40)
                    
                    // Navigation buttons
                    VStack(spacing: 25) {
                        NavigationLink(destination: SessionsDestinationView()) {
                            NavigationButtonContent(title: "Sessions")
                        }
                        
                        NavigationLink(destination: FavoritesDestinationView()) {
                            NavigationButtonContent(title: "Favorites")
                        }
                        
                        NavigationLink(destination: HiddenDestinationView()) {
                            NavigationButtonContent(title: "Hidden")
                        }
                        
                        NavigationLink(destination: TutorialDestinationView()) {
                            NavigationButtonContent(title: "Tutorial")
                        }
                        
                        NavigationLink(destination: StoreDestinationView()) {
                            NavigationButtonContent(title: "Store")
                        }
                    }
                    .padding(.horizontal, 50)
                    
                    Spacer(minLength: 40)
                    
                    // Bottom filagree container - positioned correctly at the bottom edge
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
        .navigationBarHidden(true)
    }
}

// Destination view structs
struct SessionsDestinationView: View {
    var body: some View {
        Text("Sessions View")
            .navigationBarTitle("Sessions")
    }
}

struct FavoritesDestinationView: View {
    var body: some View {
        Text("Favorites View")
            .navigationBarTitle("Favorites")
    }
}

struct HiddenDestinationView: View {
    var body: some View {
        Text("Hidden View")
            .navigationBarTitle("Hidden")
    }
}

struct TutorialDestinationView: View {
    var body: some View {
        Text("Tutorial View")
            .navigationBarTitle("Tutorial")
    }
}

struct StoreDestinationView: View {
    var body: some View {
        Text("Store View")
            .navigationBarTitle("Store")
    }
}

// Button content for navigation links
struct NavigationButtonContent: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .regular, design: .default))
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

#Preview {
    NavigationView {
        HomeView()
    }
} 