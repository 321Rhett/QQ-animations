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

struct ContentView: View {
    // ViewModel for database access
    @StateObject private var viewModel = QuestionViewModel()
    
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
    
    init() {
        // This is not needed in SwiftUI but included for clarity
        // State and StateObject are automatically initialized
        
        // Note: We'll keep ContentView's state for animations
        // But these will be synced with the ViewModel through our toggle functions
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
                            .font(.system(size: 24, weight: .bold))
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
                        .fill(Color.topOverlay)
                        .frame(height: geometry.size.height - topBarHeight)
                    
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
                
                // Bottom Overlay with handle and body
                VStack(spacing: 0) {
                    // Bottom overlay handle - draggable
                    ZStack {
                        Rectangle()
                            .fill(Color.appBackground)
                            .frame(height: bottomBarHeight)
                        
                        // Add filagree to handle, flipped vertically
                        FilagreeView(color: isFavorite ? .favoriteHandle : (isHidden ? .hiddenHandle : .filagree), isFlipped: true)
                            .frame(height: bottomBarHeight * 0.8)
                            .padding(.horizontal)
                    }
                    .contentShape(Rectangle()) // Ensure entire handle is tappable
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                // Activate this overlay while dragging
                                bottomOverlayActive = true
                                
                                // On first touch, record the initial touch location and handle position
                                if initialBottomDragLocation == 0 {
                                    initialBottomDragLocation = value.location.y
                                    initialBottomHandlePosition = bottomOverlayOffset
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
                                        } else {
                                            // Moved downward - retract fully
                                            bottomOverlayOffset = 0
                                            bottomOverlayActive = false
                                        }
                                    } else {
                                        // If we haven't moved far enough, go back to where we started
                                        bottomOverlayOffset = initialBottomHandlePosition
                                        bottomOverlayActive = initialBottomHandlePosition > 0
                                    }
                                }
                                
                                // Reset the tracking variables for next drag
                                initialBottomDragLocation = 0
                            }
                    )
                    
                    // Bottom overlay body
                    Rectangle()
                        .fill(Color.bottomOverlay)
                        .frame(height: geometry.size.height - bottomBarHeight)
                }
                .offset(y: geometry.size.height - bottomBarHeight - safeAreaBottom - bottomOverlayOffset)
                .zIndex(bottomOverlayActive ? 2 : 1)
                .animation(.quickTransition, value: bottomOverlayOffset)
            }
            // Watch for changes in the ViewModel
            .onChange(of: viewModel.isFavorite) { newValue in
                // Update the ContentView state to match
                isFavorite = newValue
            }
            .onChange(of: viewModel.isHidden) { newValue in
                // Update the ContentView state to match
                isHidden = newValue
            }
        }
        .ignoresSafeArea()
    }
}

// More explicit preview provider for better compatibility
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice(PreviewDevice(rawValue: "iPhone 15"))
            .previewDisplayName("iPhone 15")
    }
}

// Use the correct #Preview macro syntax
#if DEBUG
#Preview("QQ animations - iPhone 15") {
    ContentView()
}
#endif
