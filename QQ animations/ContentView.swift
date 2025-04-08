//
//  ContentView.swift
//  QQ animations
//
//  Created by Rhett Wilhoit on 3/28/25.
//
// Note: SF Symbols have been replaced with custom PDF symbols from the Assets.xcassets/PDF Symbols folder

import SwiftUI
import UIKit

// UIKit extension to get safe area insets
extension UIApplication {
    static var safeAreaInsets: UIEdgeInsets {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets ?? .zero
    }
}

// Animation constants for consistent timing
extension Animation {
    static let quickTransition = Animation.easeInOut(duration: 0.3)
    static let mediumTransition = Animation.easeInOut(duration: 0.4)
    static let longTransition = Animation.easeInOut(duration: 0.9)
}

// App timing constants
enum AppTiming {
    static let quick: Double = 0.3
    static let medium: Double = 0.4
    static let long: Double = 0.9
    static let shortDelay: Double = 0.1
    static let mediumDelay: Double = 0.3
}

// Extension for high-quality image rendering
extension Image {
    func highQualityImageRendering() -> some View {
        self
            .interpolation(.high)
            .antialiased(true)
    }
}

// Reusable two-finger swipe to dismiss gesture modifier
struct TwoFingerSwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var offset: CGFloat = 0
    @State private var isDismissing = false
    @State private var didProvideFeedback = false
    @State private var showDismissIndicator = false
    
    // Configuration
    let dismissThreshold: CGFloat
    let feedbackThreshold: CGFloat
    
    init(dismissThreshold: CGFloat = 100, feedbackThreshold: CGFloat = 50) {
        self.dismissThreshold = dismissThreshold
        self.feedbackThreshold = feedbackThreshold
    }
    
    // Calculate the progress towards dismissal (0.0 - 1.0)
    private func dismissProgress() -> CGFloat {
        let progress = min(1.0, abs(offset) / dismissThreshold)
        return progress
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .offset(x: offset)
                .opacity(1.0 - dismissProgress() * 0.3)
            
            // Dismiss indicator
            VStack {
                Spacer()
                
                if showDismissIndicator {
                    Text("Release to go back")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .transition(.opacity)
                        .opacity(dismissProgress())
                }
                
                Spacer().frame(height: 40)
            }
        }
        .background(Color.appBackground) // Match the app's background color
        .onAppear {
            // Create and configure the gesture recognizer
            let gestureRecognizer = TwoFingerSwipeGestureRecognizer(
                onChanged: { translation in
                    if !isDismissing {
                        offset = translation.x
                        
                        // Show dismiss indicator when approaching threshold
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDismissIndicator = offset > feedbackThreshold
                        }
                        
                        // Provide haptic feedback when crossing the feedback threshold
                        if offset > feedbackThreshold && !didProvideFeedback {
                            didProvideFeedback = true
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        } else if offset < feedbackThreshold && didProvideFeedback {
                            // Reset feedback flag when going back below threshold
                            didProvideFeedback = false
                        }
                    }
                },
                onEnded: { translation in
                    if offset > dismissThreshold && !isDismissing {
                        // If swiped beyond threshold, dismiss
                        isDismissing = true
                        
                        // Provide success haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        // Animate the dismissal with a proper navigation transition
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset = UIScreen.main.bounds.width
                            showDismissIndicator = false
                        }
                        
                        // Slight delay before actual dismissal to let animation complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    } else {
                        // Reset feedback flag
                        didProvideFeedback = false
                        
                        // Hide dismiss indicator
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDismissIndicator = false
                        }
                        
                        // Otherwise, bounce back with a spring animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                    }
                }
            )
            
            // Add the gesture recognizer to the window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addGestureRecognizer(gestureRecognizer)
            }
        }
    }
    
    private func performDismiss() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let navigationController = window.rootViewController as? UINavigationController {
                navigationController.popViewController(animated: true)
            }
        }
    }
}

// Custom gesture recognizer for two-finger swipes
class TwoFingerSwipeGestureRecognizer: UIGestureRecognizer {
    private var onChanged: (CGPoint) -> Void
    private var onEnded: (CGPoint) -> Void
    private var initialTouchLocations: [CGPoint] = []
    private var currentTouchLocations: [CGPoint] = []
    
    init(onChanged: @escaping (CGPoint) -> Void, onEnded: @escaping (CGPoint) -> Void) {
        self.onChanged = onChanged
        self.onEnded = onEnded
        super.init(target: nil, action: nil)
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        // Only proceed if we have exactly two touches
        if touches.count == 2 {
            initialTouchLocations = touches.map { $0.location(in: nil) }
            currentTouchLocations = initialTouchLocations
            state = .began
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        // Only proceed if we have exactly two touches
        if touches.count == 2 {
            currentTouchLocations = touches.map { $0.location(in: nil) }
            
            // Calculate the average translation
            let initialCenter = CGPoint(
                x: (initialTouchLocations[0].x + initialTouchLocations[1].x) / 2,
                y: (initialTouchLocations[0].y + initialTouchLocations[1].y) / 2
            )
            let currentCenter = CGPoint(
                x: (currentTouchLocations[0].x + currentTouchLocations[1].x) / 2,
                y: (currentTouchLocations[0].y + currentTouchLocations[1].y) / 2
            )
            
            let translation = CGPoint(
                x: currentCenter.x - initialCenter.x,
                y: currentCenter.y - initialCenter.y
            )
            
            onChanged(translation)
            state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if touches.count == 2 {
            let finalCenter = CGPoint(
                x: (currentTouchLocations[0].x + currentTouchLocations[1].x) / 2,
                y: (currentTouchLocations[0].y + currentTouchLocations[1].y) / 2
            )
            let initialCenter = CGPoint(
                x: (initialTouchLocations[0].x + initialTouchLocations[1].x) / 2,
                y: (initialTouchLocations[0].y + initialTouchLocations[1].y) / 2
            )
            
            let translation = CGPoint(
                x: finalCenter.x - initialCenter.x,
                y: finalCenter.y - initialCenter.y
            )
            
            onEnded(translation)
            state = .ended
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }
}

// Extension to make the modifier easier to use
extension View {
    func twoFingerSwipeToDismiss(
        dismissThreshold: CGFloat = 100,
        feedbackThreshold: CGFloat = 50
    ) -> some View {
        self.modifier(TwoFingerSwipeToDismissModifier(
            dismissThreshold: dismissThreshold,
            feedbackThreshold: feedbackThreshold
        ))
    }
}

// Reusable filagree component
struct FilagreeView: View {
    let color: Color
    let isFlipped: Bool
    
    var body: some View {
        Image("filagree")
            .resizable()
            .highQualityImageRendering()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(color)
            .rotation3DEffect(
                isFlipped ? .degrees(180) : .degrees(0),
                axis: (x: 1.0, y: 0.0, z: 0.0)
            )
    }
}

// Reusable action symbol component
struct ActionSymbol: View {
    let symbolName: String
    let color: Color
    let size: CGFloat
    let scale: CGFloat
    let opacity: Double
    let xOffset: CGFloat
    let yOffset: CGFloat
    
    var body: some View {
        // Use a larger base size and scale down for better rendering quality
        let scaledSize = size * max(3.0, scale) // Use a minimum of 3x base size
        
        Image(symbolName)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .foregroundColor(color)
            .frame(width: scaledSize, height: scaledSize)
            .scaleEffect(scale / max(3.0, scale)) // Adjust scale factor
            .opacity(opacity)
            .offset(x: xOffset, y: yOffset)
            .allowsHitTesting(false) // Prevent symbol from blocking card gesture
    }
}

// Add this extension near the top of the file with the other extensions
extension UITextView {
    open override var backgroundColor: UIColor? {
        get { return .clear }
        set { }
    }
}

// Add this further down where our other view extensions are
struct CustomTextEditorStyle: ViewModifier {
    var backgroundColor: Color
    var textColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(textColor)
            .padding()
            .background(backgroundColor)
            .onAppear {
                // This more aggressive approach changes the appearance for all TextViews
                UITextView.appearance().backgroundColor = UIColor(backgroundColor)
                UITextView.appearance().textColor = UIColor(textColor)
            }
    }
}

extension View {
    func customTextEditorStyle(backgroundColor: Color, textColor: Color) -> some View {
        self.modifier(CustomTextEditorStyle(backgroundColor: backgroundColor, textColor: textColor))
    }
}

struct ContentView: View {
    @StateObject private var viewModel = QuestionViewModel()
    @StateObject private var notesViewModel: NotesViewModel
    let session: Session?
    
    // Add missing state variables
    @State private var isQuestionVisible = false
    @FocusState private var isNotesFocused: Bool
    
    // States for the overlay positions
    @State private var topOverlayOffset: CGFloat = 0
    @State private var bottomOverlayOffset: CGFloat = 0
    
    // Track which overlay is active (being dragged/open)
    @State private var topOverlayActive: Bool = false
    @State private var bottomOverlayActive: Bool = false
    
    // Store drag gesture locations to enable smooth dragging
    @State private var initialTopDragLocation: CGFloat = 0
    @State private var initialTopHandlePosition: CGFloat = 0
    @State private var initialBottomDragLocation: CGFloat = 0
    @State private var initialBottomHandlePosition: CGFloat = 0
    
    // States for horizontal card swipe
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 1.0
    @State private var symbolOffset: CGFloat = 0
    @State private var symbolOpacity: Double = 0.0
    @State private var symbolScale: CGFloat = 0.6
    @State private var isShowingSkipSymbol: Bool = false
    @State private var isShowingCompleteSymbol: Bool = false
    @State private var isCardSwiped: Bool = false
    
    // States for vertical card swipe
    @State private var isFavorite: Bool = false
    @State private var isHidden: Bool = false
    @State private var isShowingFavoriteSymbol: Bool = false
    @State private var isShowingHiddenSymbol: Bool = false
    @State private var verticalSymbolOffset: CGFloat = 0
    @State private var verticalSymbolOpacity: Double = 0.0
    @State private var verticalSymbolScale: CGFloat = 0.6
    @State private var isVerticalSwipeInProgress: Bool = false // Prevent multiple vertical swipes
    
    // Constants for overlay sizes
    let topBarHeight: CGFloat = 50
    let bottomBarHeight: CGFloat = 50
    let cardHeight: CGFloat = 300
    
    // Constants for swipe thresholds
    let horizontalSwipeThreshold: CGFloat = 100
    let verticalSwipeThreshold: CGFloat = 100
    let symbolSize: CGFloat = 60
    let overlayTriggerThresholdFraction: CGFloat = 8 // 1/8 of full distance triggers overlay state change
    
    // Get the safe area insets directly from UIKit
    var safeAreaTop: CGFloat {
        UIApplication.safeAreaInsets.top
    }
    
    var safeAreaBottom: CGFloat {
        UIApplication.safeAreaInsets.bottom
    }
    
    // Get handle color based on current state
    func handleColor(isTop: Bool) -> Color {
        if isHidden {
            return .hiddenHandle
        } else if isFavorite {
            return .favoriteHandle
        } else {
            return isTop ? .topHandle : .bottomHandle
        }
    }
    
    // Calculate extra padding needed for Dynamic Island or notch
    var dynamicIslandPadding: CGFloat {
        // Get top safe area inset
        let topInset = UIApplication.safeAreaInsets.top
        
        // All models with notches or Dynamic Island have top insets greater than standard
        // (iPhone 8 and earlier have top insets of 20pt, while notched phones have 44pt or greater)
        if topInset >= 44 {
            // Dynamic Island models have even larger insets (54+)
            if topInset > 50 {
                return 30 // Additional padding for Dynamic Island models
            } else {
                return 20 // Padding for notched models (X, XR, XS, 11, 12, 13)
            }
        } else {
            return 0 // No extra padding for older non-notched models
        }
    }
    
    // Helper function to calculate swipe progress effects
    func calculateSwipeProgress(distance: CGFloat, threshold: CGFloat) -> (opacity: Double, scale: CGFloat) {
        let progress = min(1.0, abs(distance) / threshold)
        let opacity = min(1.0, Double(progress) * 0.8)
        let scale = 0.6 + min(1.4, progress * 1.0)
        return (opacity, scale)
    }
    
    // Reset the card horizontal state but only when returning from a partial swipe
    func resetCardState() {
        withAnimation(.quickTransition) {
            // Return card to center
            cardOffset = 0
            
            // Reset the opacity to hide the symbol
            symbolOpacity = 0
            
            // Keep scale at initial state
            symbolScale = 0.6
            
            // For symbolOffset, we need to handle it differently
            // We don't want to set it to 0 (center) but return it to the edge
            // We'll handle this by setting the position far offscreen,
            // since the symbol will be invisible anyway due to 0 opacity
            if isShowingSkipSymbol {
                symbolOffset = UIScreen.main.bounds.width / 2 // Right edge
            } else if isShowingCompleteSymbol {
                symbolOffset = -UIScreen.main.bounds.width / 2 // Left edge
            }
            
            cardOpacity = 1.0
            
            // Reset the flags after short delay to prevent flicker
            DispatchQueue.main.asyncAfter(deadline: .now() + AppTiming.shortDelay) {
                isShowingSkipSymbol = false
                isShowingCompleteSymbol = false
                isCardSwiped = false
            }
        }
    }
    
    // Reset vertical swipe state
    func resetVerticalCardState() {
        // Skip resetting if a swipe is already in progress
        if isVerticalSwipeInProgress {
            return
        }
        
        withAnimation(.quickTransition) {
            verticalSymbolOpacity = 0
            verticalSymbolScale = 0.6
            
            // Position symbol at the centermost edge of the handles
            if isShowingFavoriteSymbol {
                // Position at bottom handle's inner edge (at center of screen, just below card)
                verticalSymbolOffset = (UIScreen.main.bounds.height / 2) - bottomBarHeight - safeAreaBottom
            } else if isShowingHiddenSymbol {
                // Position at top handle's inner edge (at center of screen, just above card)
                // Use the same distance from center as the favorite symbol for consistency
                verticalSymbolOffset = -((UIScreen.main.bounds.height / 2) - bottomBarHeight - safeAreaBottom)
            }
            
            // Reset the flags after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + AppTiming.shortDelay) {
                isShowingFavoriteSymbol = false
                isShowingHiddenSymbol = false
            }
        }
    }
    
    // Toggle favorite state
    func toggleFavorite() {
        withAnimation(.quickTransition) {
            // Move symbol to center and scale up
            verticalSymbolOffset = 0
            verticalSymbolOpacity = 1.0
            verticalSymbolScale = 3.0
            
            // Toggle the favorite state and make sure hidden is off
            if !isFavorite {
                isFavorite = true
                isHidden = false
                viewModel.toggleFavorite() // Save to database
            } else {
                isFavorite = false
                viewModel.toggleFavorite() // Save to database
            }
        }
        
        // After a delay, fade out the symbol
        DispatchQueue.main.asyncAfter(deadline: .now() + AppTiming.long) {
            withAnimation(.mediumTransition) {
                verticalSymbolOpacity = 0
            }
            
            // Don't reset isShowingFavoriteSymbol here - wait for the animation to complete
            // This allows repeated swipes in the same direction to work correctly
        }
    }
    
    // Toggle hidden state
    func toggleHidden() {
        withAnimation(.quickTransition) {
            // Move symbol to center and scale up
            verticalSymbolOffset = 0
            verticalSymbolOpacity = 1.0
            verticalSymbolScale = 3.0
            
            // Toggle the hidden state and make sure favorite is off
            if !isHidden {
                isHidden = true
                isFavorite = false
                viewModel.toggleHidden() // Save to database
            } else {
                isHidden = false
                viewModel.toggleHidden() // Save to database
            }
        }
        
        // After a delay, fade out the symbol
        DispatchQueue.main.asyncAfter(deadline: .now() + AppTiming.long) {
            withAnimation(.mediumTransition) {
                verticalSymbolOpacity = 0
            }
            
            // Don't reset isShowingHiddenSymbol here - wait for the animation to complete
            // This allows repeated swipes in the same direction to work correctly
        }
    }
    
    // Animate the card swipe completion
    func completeCardSwipe(direction: CGFloat) {
        // DON'T fetch a new question yet - we'll do that after the card is off screen
        
        withAnimation(.quickTransition) {
            // Move card completely off screen
            cardOffset = direction * UIScreen.main.bounds.width * 1.5
            cardOpacity = 0
            
            // Move symbol to center and scale up (3x the original size)
            symbolOffset = 0 // Move to exact center of screen
            symbolOpacity = 1.0
            symbolScale = 3.0 // Increased from 1.2 to 3.0
            isCardSwiped = true
        }
        
        // After a delay, fade out symbol and prepare for new card
        DispatchQueue.main.asyncAfter(deadline: .now() + AppTiming.long) {
            withAnimation(.quickTransition) {
                symbolOpacity = 0
            }
            
            // After symbol fades out, set up the new card
            DispatchQueue.main.asyncAfter(deadline: .now() + AppTiming.mediumDelay) {
                // THIS is when we should fetch a new question - after the old card is gone
                viewModel.fetchRandomQuestion()
                
                // Reset position without animation while card is invisible
                cardOffset = 0
                isShowingSkipSymbol = false
                isShowingCompleteSymbol = false
                isCardSwiped = false
                
                // Now fade in the main card with the new content
                withAnimation(.mediumTransition) {
                    cardOpacity = 1.0
                }
            }
        }
    }
    
    // Card container symbols
    var skipSymbol: some View {
        ActionSymbol(
            symbolName: "skip symbol",
            color: .skipSymbol,
            size: symbolSize,
            scale: symbolScale,
            opacity: isShowingSkipSymbol ? symbolOpacity : 0,
            xOffset: symbolOffset,
            yOffset: 0
        )
    }
    
    var completeSymbol: some View {
        ActionSymbol(
            symbolName: "completed symbol",
            color: .completeSymbol,
            size: symbolSize,
            scale: symbolScale,
            opacity: isShowingCompleteSymbol ? symbolOpacity : 0,
            xOffset: symbolOffset,
            yOffset: 0
        )
    }
    
    var favoriteSymbol: some View {
        ActionSymbol(
            symbolName: "favorite symbol",
            color: .favoriteSymbol,
            size: symbolSize,
            scale: verticalSymbolScale,
            opacity: isShowingFavoriteSymbol ? verticalSymbolOpacity : 0,
            xOffset: 0,
            yOffset: verticalSymbolOffset
        )
    }
    
    var hiddenSymbol: some View {
        ActionSymbol(
            symbolName: "hidden symbol",
            color: .hiddenSymbol,
            size: symbolSize,
            scale: verticalSymbolScale,
            opacity: isShowingHiddenSymbol ? verticalSymbolOpacity : 0,
            xOffset: 0,
            yOffset: verticalSymbolOffset
        )
    }
    
    // Add state for keyboard height near other state variables
    @State private var keyboardHeight: CGFloat = 0
    
    // Add a new state to track whether the overlay is in transition
    @State private var isOverlayTransitioning: Bool = false
    
    init(session: Session?) {
        self.session = session
        _notesViewModel = StateObject(wrappedValue: NotesViewModel(
            sessionId: session?.id ?? -1,
            questionId: -1  // We'll update this when a question is loaded
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main background
                Color.appBackground.ignoresSafeArea()
                
                // Main content stack
                VStack(spacing: 0) {
                    // Top bar with correct positioning
                    ZStack(alignment: .top) {
                        // Safe area spacer
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: safeAreaTop)
                        
                        // Top bar positioned below safe area - make transparent but keep for layout
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: topBarHeight)
                            .offset(y: safeAreaTop)
                    }
                    .frame(height: safeAreaTop + topBarHeight)
                    
                    Spacer()
                    
                    // Card container
                    ZStack {
                        // Create a gesture container that covers the entire card area
                        Rectangle()
                            .fill(Color.clear) // Make it transparent
                            .frame(height: cardHeight)
                            .padding(.horizontal)
                            .contentShape(Rectangle()) // Ensure the entire area is tappable
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // Only respond if not already swiped
                                        if !isCardSwiped {
                                            // Get distance of vertical/horizontal move
                                            let verticalDistance = value.translation.height
                                            let horizontalDistance = value.translation.width
                                            
                                            // Determine if this is primarily a vertical or horizontal swipe
                                            if abs(verticalDistance) > abs(horizontalDistance) {
                                                // Vertical swipe - we don't move the card vertically anymore
                                                // Only respond if there isn't already a vertical swipe in progress
                                                if !isVerticalSwipeInProgress {
                                                    // If we were showing horizontal symbols, hide them when switching to vertical
                                                    if isShowingSkipSymbol || isShowingCompleteSymbol {
                                                        symbolOpacity = 0
                                                        isShowingSkipSymbol = false
                                                        isShowingCompleteSymbol = false
                                                        // Reset horizontal offset too
                                                        cardOffset = 0
                                                    }
                                                    
                                                    // Handle up vs down swipe for symbols
                                                    if verticalDistance < 0 {
                                                        // Swiping up - show favorite symbol
                                                        isShowingFavoriteSymbol = true
                                                        isShowingHiddenSymbol = false
                                                        
                                                        // Update symbol from bottom handle's centermost edge
                                                        let bottomHandleEdge = (geometry.size.height / 2) - bottomBarHeight - safeAreaBottom
                                                        verticalSymbolOffset = bottomHandleEdge + verticalDistance/2
                                                        
                                                        // Calculate progress
                                                        let progressValues = calculateSwipeProgress(distance: verticalDistance, threshold: verticalSwipeThreshold)
                                                        verticalSymbolOpacity = progressValues.opacity
                                                        verticalSymbolScale = progressValues.scale
                                                        
                                                    } else if verticalDistance > 0 {
                                                        // Swiping down - show hidden symbol
                                                        isShowingHiddenSymbol = true
                                                        isShowingFavoriteSymbol = false
                                                        
                                                        // Update symbol from top handle's centermost edge
                                                        let bottomHandleEdge = (geometry.size.height / 2) - bottomBarHeight - safeAreaBottom
                                                        verticalSymbolOffset = -bottomHandleEdge + verticalDistance/2
                                                        
                                                        // Calculate progress
                                                        let progressValues = calculateSwipeProgress(distance: verticalDistance, threshold: verticalSwipeThreshold)
                                                        verticalSymbolOpacity = progressValues.opacity
                                                        verticalSymbolScale = progressValues.scale
                                                    }
                                                }
                                            } else {
                                                // Horizontal swipe - update horizontal offset
                                                cardOffset = horizontalDistance
                                                
                                                // If we were showing vertical symbols, hide them when switching to horizontal
                                                if isShowingFavoriteSymbol || isShowingHiddenSymbol {
                                                    verticalSymbolOpacity = 0
                                                    isShowingFavoriteSymbol = false
                                                    isShowingHiddenSymbol = false
                                                }
                                                
                                                // Determine which symbol to show based on swipe direction
                                                if horizontalDistance > 0 {
                                                    // Swiping right - show complete symbol
                                                    isShowingCompleteSymbol = true
                                                    isShowingSkipSymbol = false
                                                    
                                                    // Update symbol position and opacity
                                                    symbolOffset = -geometry.size.width/2 + horizontalDistance/2
                                                    
                                                    // Calculate progress
                                                    let progressValues = calculateSwipeProgress(distance: horizontalDistance, threshold: horizontalSwipeThreshold)
                                                    symbolOpacity = progressValues.opacity
                                                    symbolScale = progressValues.scale
                                                } else if horizontalDistance < 0 {
                                                    // Swiping left - show skip symbol
                                                    isShowingSkipSymbol = true
                                                    isShowingCompleteSymbol = false
                                                    
                                                    // Update symbol position and opacity
                                                    symbolOffset = geometry.size.width/2 + horizontalDistance/2
                                                    
                                                    // Calculate progress
                                                    let progressValues = calculateSwipeProgress(distance: horizontalDistance, threshold: horizontalSwipeThreshold)
                                                    symbolOpacity = progressValues.opacity
                                                    symbolScale = progressValues.scale
                                                }
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        if !isCardSwiped {
                                            // Get distance of vertical/horizontal move
                                            let verticalDistance = value.translation.height
                                            let horizontalDistance = value.translation.width
                                            
                                            // Determine if this was primarily a vertical or horizontal swipe
                                            if abs(verticalDistance) > abs(horizontalDistance) {
                                                // Vertical swipe - check if threshold was reached
                                                if abs(verticalDistance) > verticalSwipeThreshold && !isVerticalSwipeInProgress {
                                                    // Set the flag to prevent multiple swipes
                                                    isVerticalSwipeInProgress = true
                                                    
                                                    if verticalDistance < 0 {
                                                        // Swiped up past threshold - toggle favorite
                                                        // Mark both symbols as showing false to prevent reset conflicts
                                                        isShowingHiddenSymbol = false
                                                        isShowingFavoriteSymbol = true
                                                        toggleFavorite()
                                                    } else {
                                                        // Swiped down past threshold - toggle hidden
                                                        // Mark both symbols as showing false to prevent reset conflicts
                                                        isShowingFavoriteSymbol = false
                                                        isShowingHiddenSymbol = true
                                                        toggleHidden()
                                                    }
                                                    
                                                    // Reset the flag and symbol states after the animation completes
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + AppTiming.long + AppTiming.mediumDelay) {
                                                        isVerticalSwipeInProgress = false
                                                        
                                                        // Now it's safe to reset the symbol showing flags
                                                        if !isVerticalSwipeInProgress {
                                                            isShowingFavoriteSymbol = false
                                                            isShowingHiddenSymbol = false
                                                        }
                                                    }
                                                } else if !isVerticalSwipeInProgress {
                                                    // Only reset if no swipe animation is in progress
                                                    resetVerticalCardState()
                                                }
                                            } else {
                                                // Horizontal swipe - check if threshold was reached
                                                if abs(horizontalDistance) > horizontalSwipeThreshold {
                                                    // If swiped past threshold, complete the swipe
                                                    let direction: CGFloat = horizontalDistance > 0 ? 1 : -1
                                                    completeCardSwipe(direction: direction)
                                                } else {
                                                    // Otherwise, reset card position
                                                    resetCardState()
                                                }
                                            }
                                        }
                                    }
                            )
                            .zIndex(2) // Ensure this is on top to capture all gestures
                        
                        // Current card
                        Rectangle()
                            .fill(Color.white.opacity(0.9))
                            .frame(height: cardHeight)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .offset(x: cardOffset, y: 0)
                            .opacity(cardOpacity)
                        
                        // Card content
                        Text(viewModel.questionDisplayText)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding()
                            .offset(x: cardOffset, y: 0)
                            .opacity(cardOpacity)
                            .allowsHitTesting(false) // Prevent text from intercepting touches
                        
                        // Action symbols
                        skipSymbol
                        completeSymbol
                        favoriteSymbol
                        hiddenSymbol
                    }
                    
                    Spacer()
                    
                    // Bottom bar with correct positioning
                    ZStack(alignment: .bottom) {
                        // Bottom bar positioned above safe area - make transparent but keep for layout
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: bottomBarHeight)
                        
                        // Safe area spacer
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: safeAreaBottom)
                            .offset(y: bottomBarHeight)
                    }
                    .frame(height: safeAreaBottom + bottomBarHeight)
                }
                
                // MARK: - Top Overlay
                
                // Top Overlay with body and handle
                VStack(spacing: 0) {
                    // Top overlay body
                    Rectangle()
                        .fill(Color.appBackground)
                        .frame(height: geometry.size.height - topBarHeight)
                        .overlay(
                            ScrollView {
                                VStack(spacing: 20) {
                                    // Favorites button
                                    Button(action: {
                                        // Functionality will be added later
                                    }) {
                                        Text("Favorites")
                                            .font(.system(size: 26, design: .monospaced))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.favoriteSymbol)
                                            )
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, safeAreaTop + 10 + dynamicIslandPadding)
                                    
                                    // Clear All button
                                    Button(action: {
                                        // Functionality will be added later
                                    }) {
                                        Text("Clear All")
                                            .font(.system(size: 26, design: .monospaced))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.gray.opacity(0.3))
                                            )
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, 5)
                                    
                                    // Search bar
                                    HStack {
                                        Text("⌕")
                                            .font(.system(size: 24, design: .monospaced))
                                            .foregroundColor(.gray)
                                        
                                        TextField("search word/phrase", text: .constant(""))
                                            .font(.system(size: 18, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 5)
                                    
                                    // Tags label
                                    Text("Tags")
                                        .font(.system(size: 24, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.top, 5)
                                    
                                    // Tags grid
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                        // Left column
                                        Button(action: {}) {
                                            Text("Past")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        // Right column
                                        Button(action: {}) {
                                            Text("NSFW")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Present")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Secrets")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Future")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Beliefs")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Deep")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Emotional")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Ice Breaker")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Hypothetical")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Silly")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Skills")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Adventure")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Favorite X")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("Culture")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                        
                                        Button(action: {}) {
                                            Text("This or That")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    // Packs section
                                    Text("Packs")
                                        .font(.system(size: 24, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.top, 20)
                                    
                                    // Packs grid
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                        ForEach(1...16, id: \.self) { index in
                                            Button(action: {}) {
                                                Text("core0\(index)")
                                                    .font(.system(size: 18, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 16)
                                                    .padding(.horizontal, 6)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.gray.opacity(0.3))
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 50)
                                }
                            }
                        )
                    
                    // Top overlay handle - draggable
                    ZStack {
                        Rectangle()
                            .fill(Color.appBackground)
                            .frame(height: topBarHeight)
                        
                        // Add filagree to handle
                        FilagreeView(color: isFavorite ? .favoriteHandle : (isHidden ? .hiddenHandle : .filagree), isFlipped: false)
                            .frame(height: topBarHeight * 0.8)
                            .padding(.horizontal)
                    }
                    .contentShape(Rectangle()) // Ensure entire handle is tappable
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                // Activate this overlay while dragging
                                topOverlayActive = true
                                
                                // On first touch, record the initial touch location and handle position
                                if initialTopDragLocation == 0 {
                                    initialTopDragLocation = value.location.y
                                    initialTopHandlePosition = topOverlayOffset
                                }
                                
                                // Calculate new position using direct finger tracking in global coordinates
                                let dragDistance = value.location.y - initialTopDragLocation
                                let newOffset = initialTopHandlePosition + dragDistance
                                
                                // Calculate full slide distance to position precisely at bottom bar
                                let maxOffset = geometry.size.height - (safeAreaTop + topBarHeight) - safeAreaBottom
                                
                                // Constrain within bounds - direct 1:1 movement with finger
                                topOverlayOffset = min(maxOffset, max(0, newOffset))
                            }
                            .onEnded { value in
                                // Calculate full slide distance
                                let fullSlideDistance = geometry.size.height - (safeAreaTop + topBarHeight) - safeAreaBottom
                                
                                // Calculate how far we've moved from where we started the drag
                                let dragDistance = topOverlayOffset - initialTopHandlePosition
                                
                                // Determine threshold for triggering state change
                                let threshold = fullSlideDistance / overlayTriggerThresholdFraction
                                
                                withAnimation(.quickTransition) {
                                    if abs(dragDistance) > threshold {
                                        // If we've moved more than the threshold, trigger state change
                                        if dragDistance > 0 {
                                            // Moved downward - deploy fully
                                            topOverlayOffset = fullSlideDistance
                                            topOverlayActive = true
                                        } else {
                                            // Moved upward - retract fully
                                            topOverlayOffset = 0
                                            topOverlayActive = false
                                        }
                                    } else {
                                        // If we haven't moved far enough, go back to where we started
                                        topOverlayOffset = initialTopHandlePosition
                                        topOverlayActive = initialTopHandlePosition > 0
                                    }
                                }
                                
                                // Reset the tracking variables for next drag
                                initialTopDragLocation = 0
                            }
                    )
                }
                .offset(y: -geometry.size.height + topBarHeight + safeAreaTop + topOverlayOffset)
                .zIndex(topOverlayActive ? 2 : 0)
                .animation(.quickTransition, value: topOverlayOffset)
                
                // MARK: - Bottom Overlay
                
                // Bottom overlay
                ZStack(alignment: .top) {
                    // Visual bridge to ensure no gap appears during animation
                    Rectangle()
                        .fill(Color.appBackground)
                        .frame(width: geometry.size.width, height: 4) // 4 pixels tall for extra safety
                        .position(x: geometry.size.width/2, y: bottomBarHeight) // Position at the junction
                        .zIndex(1) // High enough to cover any gap
                        .allowsHitTesting(false) // Allow touches to pass through this visual-only element
                    
                    // Single unified VStack for both handle and content
                    VStack(spacing: 0) {
                        // Handle for bottom overlay
                        ZStack {
                            Rectangle()
                                .fill(Color.appBackground)
                                .frame(height: bottomBarHeight)
                            
                            FilagreeView(color: isFavorite ? .favoriteHandle : (isHidden ? .hiddenHandle : .filagree), isFlipped: true)
                                .frame(height: bottomBarHeight * 0.8)
                                .padding(.horizontal)
                        }
                        .contentShape(Rectangle()) // Ensure entire handle is tappable
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    // Handle the case where the initial touch location is not yet set
                                    if initialBottomDragLocation == 0 {
                                        initialBottomDragLocation = value.startLocation.y
                                        initialBottomHandlePosition = bottomOverlayOffset
                                    }
                                    
                                    // Mark that we're transitioning the overlay
                                    isOverlayTransitioning = true
                                    
                                    // Activate this overlay while dragging, but don't trigger keyboard
                                    bottomOverlayActive = true
                                    
                                    // Ensure keyboard doesn't show during drag
                                    if isNotesFocused {
                                        isNotesFocused = false
                                    }
                                    
                                    // Calculate new position using direct finger tracking in global coordinates
                                    let dragDistance = initialBottomDragLocation - value.location.y
                                    let newOffset = initialBottomHandlePosition + dragDistance
                                    
                                    // Calculate full slide distance to position precisely at top bar
                                    let maxOffset = geometry.size.height - (safeAreaBottom + bottomBarHeight) - safeAreaTop
                                    
                                    // Constrain within bounds - direct 1:1 movement with finger
                                    bottomOverlayOffset = min(maxOffset, max(0, newOffset))
                                }
                                .onEnded { value in
                                    // Calculate full slide distance
                                    let fullSlideDistance = geometry.size.height - (safeAreaBottom + bottomBarHeight) - safeAreaTop
                                    
                                    // Calculate how far we've moved from where we started the drag
                                    let dragDistance = bottomOverlayOffset - initialBottomHandlePosition
                                    
                                    // Determine threshold for triggering state change
                                    let threshold = fullSlideDistance / overlayTriggerThresholdFraction
                                    
                                    withAnimation(.quickTransition) {
                                        if abs(dragDistance) > threshold {
                                            // If we've moved more than the threshold, trigger state change
                                            if dragDistance > 0 {
                                                // Moved upward - deploy fully
                                                bottomOverlayOffset = fullSlideDistance
                                                bottomOverlayActive = true
                                                
                                                // Wait until animation completes before marking transition as done
                                                // AND automatically focus the text field
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    isOverlayTransitioning = false
                                                    
                                                    // Show keyboard after overlay is fully deployed
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        if bottomOverlayActive && bottomOverlayOffset > 0 {
                                                            isNotesFocused = true
                                                        }
                                                    }
                                                }
                                            } else {
                                                // Moved downward - retract fully
                                                bottomOverlayOffset = 0
                                                bottomOverlayActive = false
                                                
                                                // Wait until animation completes before marking transition as done
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    isOverlayTransitioning = false
                                                }
                                            }
                                        } else {
                                            // If we haven't moved far enough, go back to where we started
                                            bottomOverlayOffset = initialBottomHandlePosition
                                            bottomOverlayActive = initialBottomHandlePosition > 0
                                            
                                            // Wait until animation completes before marking transition as done
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                isOverlayTransitioning = false
                                                
                                                // If we're returning to the deployed state, restore keyboard focus
                                                if initialBottomHandlePosition > 0 && bottomOverlayActive && bottomOverlayOffset > 0 {
                                                    isNotesFocused = true
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Reset the tracking variables for next drag
                                    initialBottomDragLocation = 0
                                }
                        )
                        
                        // Content section
                        VStack(spacing: 0) {
                            // Character count - centered
                            Text("\(notesViewModel.remainingCharacters) characters remaining")
                                .foregroundColor(.gray)
                                .font(.system(size: 14, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                            
                            // Main content area: TextEditor and Buttons
                            GeometryReader { contentGeometry in
                                VStack(spacing: 0) {
                                    TextEditor(text: Binding(
                                        get: { notesViewModel.noteContent },
                                        set: { notesViewModel.updateNoteContent($0) }
                                    ))
                                    .font(.system(size: 16, design: .monospaced))
                                    .multilineTextAlignment(.center)
                                    .focused($isNotesFocused)
                                    .customTextEditorStyle(backgroundColor: Color.gray.opacity(0.5), textColor: .white)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        // Save note when Done key is pressed
                                        notesViewModel.saveNote()
                                        // Dismiss keyboard and close overlay
                                        isNotesFocused = false
                                        withAnimation(.quickTransition) {
                                            bottomOverlayOffset = 0
                                            bottomOverlayActive = false
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: contentGeometry.size.height / 3)
                                    // Add a onChange modifier to detect when drag starts and lose focus
                                    .onChange(of: initialBottomDragLocation) { newValue in
                                        if newValue != 0 {
                                            // Drag has started, immediately lose focus
                                            isNotesFocused = false
                                        }
                                    }
                                    
                                    // Fixed-height buttons area at the bottom
                                    VStack {
                                        // Buttons container
                                        HStack(spacing: 16) {
                                            // Cancel button
                                            Button(action: {
                                                // Clear text, dismiss keyboard, close overlay
                                                print("Cancel button tapped")
                                                notesViewModel.clearNoteContent()
                                                isNotesFocused = false
                                                withAnimation(.quickTransition) {
                                                    bottomOverlayOffset = 0
                                                    bottomOverlayActive = false
                                                }
                                            }) {
                                                Text("Cancel")
                                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding()
                                                    .background(Color.gray.opacity(0.8))
                                                    .cornerRadius(12)
                                            }
                                            .contentShape(Rectangle()) // Ensure button is tappable across its entire area
                                            
                                            // Save button
                                            Button(action: {
                                                // Save note, dismiss keyboard, close overlay
                                                print("Save button tapped")
                                                notesViewModel.saveNote()
                                                isNotesFocused = false
                                                withAnimation(.quickTransition) {
                                                    bottomOverlayOffset = 0
                                                    bottomOverlayActive = false
                                                }
                                            }) {
                                                Text("Save")
                                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding()
                                                    .background(Color.blue)
                                                    .cornerRadius(12)
                                            }
                                            .contentShape(Rectangle()) // Ensure button is tappable across its entire area
                                        }
                                        .padding(.horizontal)
                                        .padding(.bottom, 16)
                                        .zIndex(2) // Ensure buttons have higher z-index
                                    }
                                    .frame(height: 80) // Fixed height for buttons area
                                    .background(Color.appBackground) // Make sure it has same background
                                }
                            }
                        }
                        .frame(height: geometry.size.height - bottomBarHeight)
                        .background(Color.appBackground)
                        // Content cover - hides content when docked, fades as overlay is pulled up
                        .overlay(
                            Rectangle()
                                .fill(Color.appBackground)
                                .opacity(1.0 - min(1.0, (bottomOverlayOffset / (geometry.size.height * 0.3))))
                                .allowsHitTesting(false) // Let touches pass through
                        )
                    }
                }
                .offset(y: geometry.size.height - bottomBarHeight - safeAreaBottom - bottomOverlayOffset)
                .zIndex(bottomOverlayActive ? 2 : 1)
                .onChange(of: bottomOverlayActive) { isActive in
                    // Clear focus if the overlay is being closed
                    if !isActive {
                        isNotesFocused = false
                    }
                    
                    // We don't need additional logic here since we're handling focus in the drag gesture
                }
                .animation(.quickTransition, value: bottomOverlayOffset)
                
                // Extra listener to ensure keyboard hides when drag starts
                .onChange(of: initialBottomDragLocation) { value in
                    // If we're starting to drag down from deployed position, hide keyboard immediately
                    if value != 0 && bottomOverlayOffset > 0 {
                        // Just hide the keyboard during the drag - focus state will be restored if needed in the drag's onEnded
                        isNotesFocused = false
                    }
                }
            }
            // Add keyboard observers when the view appears
            .onAppear {
                setupKeyboardObservers()
                loadNewQuestion() // Load initial question
            }
            .onDisappear(perform: removeKeyboardObservers)
            .onReceive(viewModel.$questionPreference.map { $0?.isFavorite ?? false }) { newValue in
                // Update the ContentView state to match
                isFavorite = newValue
            }
            .onReceive(viewModel.$questionPreference.map { $0?.isHidden ?? false }) { newValue in
                // Update the ContentView state to match
                isHidden = newValue
            }
        }
        .navigationBarBackButtonHidden(true) // Hide the back button
        .twoFingerSwipeToDismiss(
            dismissThreshold: 100,  // Swipe 100 points to trigger dismissal
            feedbackThreshold: 50   // Show feedback at 50 points
        )
        .ignoresSafeArea()
    }
    
    // Simplify keyboard observers since we're not using dynamic padding anymore
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
            // Just track keyboard visibility state
            withAnimation(.quickTransition) {
                keyboardHeight = 1 // Just set to 1 as a flag that keyboard is visible
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            // Reset keyboard visibility state
            withAnimation(.quickTransition) {
                keyboardHeight = 0
            }
        }
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func loadNewQuestion() {
        viewModel.fetchRandomQuestion()
        if let question = viewModel.currentQuestion {
            notesViewModel.updateQuestion(sessionId: session?.id ?? -1, questionId: question.id)
            withAnimation(.quickTransition) {
                isQuestionVisible = true
            }
        }
    }
}

// Update preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(session: nil)
            .previewDevice(PreviewDevice(rawValue: "iPhone 15"))
            .previewDisplayName("iPhone 15")
    }
}

#if DEBUG
#Preview("QQ animations - iPhone 15") {
    ContentView(session: nil)
}
#endif
