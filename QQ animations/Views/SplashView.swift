import SwiftUI

struct SplashView: View {
    // Animation states
    @State private var quickTextOffset: CGFloat = 600
    @State private var questionTextOffset: CGFloat = -600
    @State private var taglineOpacity: Double = 0
    
    // Font constants
    private let titleFont = Font.system(size: 60, weight: .light, design: .monospaced)
    private let taglineFont = Font.system(size: 18, weight: .thin, design: .monospaced)
    
    // Animation timing constants
    private let animationDuration = 0.6
    private let quickDelay = 0.3
    private let questionDelay = 0.6
    private let taglineDelay = 1.2
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()
                
                // Logo content
                VStack(spacing: 0) {
                    Spacer()
                    
                    logoView(screenWidth: geometry.size.width)
                    
                    Spacer()
                }
            }
            .onAppear(perform: animateEntrance)
        }
    }
    
    // MARK: - View Components
    
    private func logoView(screenWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo text container
            VStack(alignment: .leading, spacing: -12) {
                Text("Quick")
                    .font(titleFont)
                    .foregroundColor(.white)
                    .offset(x: quickTextOffset)
                
                Text("Question")
                    .font(titleFont)
                    .foregroundColor(.white)
                    .padding(.leading, 38)
                    .offset(x: questionTextOffset)
            }
            .frame(width: min(400, screenWidth * 0.9), alignment: .leading)
            
            // Tagline
            Text("conversation creates connection")
                .font(taglineFont)
                .foregroundColor(Color(white: 0.5))
                .opacity(taglineOpacity)
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Quick text animation
        withAnimation(.easeOut(duration: animationDuration).delay(quickDelay)) {
            quickTextOffset = 0
        }
        
        // Question text animation
        withAnimation(.easeOut(duration: animationDuration).delay(questionDelay)) {
            questionTextOffset = 0
        }
        
        // Tagline fade in
        withAnimation(.easeIn(duration: 0.4).delay(taglineDelay)) {
            taglineOpacity = 1.0
        }
    }
}

#Preview {
    SplashView()
} 