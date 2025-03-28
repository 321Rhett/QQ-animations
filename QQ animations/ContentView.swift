//
//  ContentView.swift
//  QQ animations
//
//  Created by Rhett Wilhoit on 3/28/25.
//

import SwiftUI
import UIKit

// UIKit extension to get safe area insets
extension UIApplication {
    static var safeAreaInsets: UIEdgeInsets {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets ?? .zero
    }
}

struct ContentView: View {
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
    @State private var cardVerticalOffset: CGFloat = 0
    @State private var isFavorite: Bool = false
    @State private var isHidden: Bool = false
    @State private var isShowingFavoriteSymbol: Bool = false
    @State private var isShowingHiddenSymbol: Bool = false
    @State private var verticalSymbolOffset: CGFloat = 0
    @State private var verticalSymbolOpacity: Double = 0.0
    @State private var verticalSymbolScale: CGFloat = 0.6
    
    // State for the card text (random number for testing)
    @State private var cardText: String = "\(Int.random(in: 1000000...9999999))"
    @State private var newCardText: String = "\(Int.random(in: 1000000...9999999))"
    
    // Constants for overlay sizes
    let topBarHeight: CGFloat = 50
    let bottomBarHeight: CGFloat = 50
    let cardHeight: CGFloat = 300
    
    // Constants for swipe thresholds
    let horizontalSwipeThreshold: CGFloat = 100
    let verticalSwipeThreshold: CGFloat = 100
    let symbolSize: CGFloat = 40
    let overlayTriggerThresholdFraction: CGFloat = 8 // 1/8 of full distance triggers overlay state change
    
    // Defined colors for better consistency
    let topHandleColor = Color(red: 0.0, green: 0.4, blue: 0.8) // Deeper blue
    let topOverlayColor = Color(red: 0.1, green: 0.5, blue: 0.9) // Lighter blue
    let bottomHandleColor = Color(red: 0.5, green: 0.0, blue: 0.7) // Deep purple
    let bottomOverlayColor = Color(red: 0.6, green: 0.1, blue: 0.8) // Lighter purple
    let skipSymbolColor = Color(red: 0.6, green: 0.2, blue: 0.2) // Red
    let completeSymbolColor = Color(red: 0.2, green: 0.6, blue: 0.2) // Green
    let favoriteSymbolColor = Color(red: 0.8, green: 0.7, blue: 0.0) // Gold
    let hiddenSymbolColor = Color(red: 0.7, green: 0.0, blue: 0.0) // Dark red
    
    // Colors for when favorites or hidden is active
    let favoriteHandleColor = Color(red: 0.8, green: 0.7, blue: 0.0) // Gold
    let favoriteOverlayColor = Color(red: 0.9, green: 0.8, blue: 0.2) // Light gold
    let hiddenHandleColor = Color(red: 0.7, green: 0.0, blue: 0.0) // Dark red
    let hiddenOverlayColor = Color(red: 0.8, green: 0.1, blue: 0.1) // Light red
    
    // Get the safe area insets directly from UIKit
    var safeAreaTop: CGFloat {
        UIApplication.safeAreaInsets.top
    }
    
    var safeAreaBottom: CGFloat {
        UIApplication.safeAreaInsets.bottom
    }
    
    // Reset the card horizontal state but only when returning from a partial swipe
    func resetCardState() {
        withAnimation(.easeInOut(duration: 0.3)) {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isShowingSkipSymbol = false
                isShowingCompleteSymbol = false
                isCardSwiped = false
            }
        }
    }
    
    // Reset vertical swipe state
    func resetVerticalCardState() {
        withAnimation(.easeInOut(duration: 0.3)) {
            cardVerticalOffset = 0
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isShowingFavoriteSymbol = false
                isShowingHiddenSymbol = false
            }
        }
    }
    
    // Toggle favorite state
    func toggleFavorite() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Move symbol to center and scale up
            verticalSymbolOffset = 0
            verticalSymbolOpacity = 1.0
            verticalSymbolScale = 3.0
            cardVerticalOffset = 0 // Reset card position
            
            // Toggle the favorite state and make sure hidden is off
            if !isFavorite {
                isFavorite = true
                isHidden = false
            } else {
                isFavorite = false
            }
        }
        
        // After a delay, fade out the symbol
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.4)) {
                verticalSymbolOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isShowingFavoriteSymbol = false
            }
        }
    }
    
    // Toggle hidden state
    func toggleHidden() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Move symbol to center and scale up
            verticalSymbolOffset = 0
            verticalSymbolOpacity = 1.0
            verticalSymbolScale = 3.0
            cardVerticalOffset = 0 // Reset card position
            
            // Toggle the hidden state and make sure favorite is off
            if !isHidden {
                isHidden = true
                isFavorite = false
            } else {
                isHidden = false
            }
        }
        
        // After a delay, fade out the symbol
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.4)) {
                verticalSymbolOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isShowingHiddenSymbol = false
            }
        }
    }
    
    // Prepare a new card
    func prepareNewCard() {
        // Generate a new random number for the next card
        newCardText = "\(Int.random(in: 1000000...9999999))"
    }
    
    // Animate the card swipe completion
    func completeCardSwipe(direction: CGFloat) {
        // Prepare the next card before animation
        prepareNewCard()
        
        withAnimation(.easeInOut(duration: 0.3)) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.3)) {
                symbolOpacity = 0
            }
            
            // After symbol fades out, set up the new card
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Update the main card text to the new card's text
                cardText = newCardText
                
                // Reset position without animation while card is invisible
                cardOffset = 0
                isShowingSkipSymbol = false
                isShowingCompleteSymbol = false
                isCardSwiped = false
                
                // Now fade in the main card with the new content
                withAnimation(.easeInOut(duration: 0.4)) {
                    cardOpacity = 1.0
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main background
                Color.white.ignoresSafeArea()
                
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
                        // Current card
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: cardHeight)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .offset(x: cardOffset, y: 0)
                            .opacity(cardOpacity)
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
                                                // Vertical swipe - don't move the card vertically anymore
                                                // Instead just track the distance for symbol animation
                                                cardVerticalOffset = 0 // Keep card in place
                                                
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
                                                    let swipeProgress = min(1.0, abs(verticalDistance) / verticalSwipeThreshold)
                                                    verticalSymbolOpacity = min(1.0, Double(swipeProgress) * 0.8)
                                                    verticalSymbolScale = 0.6 + min(1.4, swipeProgress * 1.0)
                                                    
                                                } else if verticalDistance > 0 {
                                                    // Swiping down - show hidden symbol
                                                    isShowingHiddenSymbol = true
                                                    isShowingFavoriteSymbol = false
                                                    
                                                    // Update symbol from top handle's centermost edge
                                                    let bottomHandleEdge = (geometry.size.height / 2) - bottomBarHeight - safeAreaBottom
                                                    verticalSymbolOffset = -bottomHandleEdge + verticalDistance/2
                                                    
                                                    // Calculate progress
                                                    let swipeProgress = min(1.0, abs(verticalDistance) / verticalSwipeThreshold)
                                                    verticalSymbolOpacity = min(1.0, Double(swipeProgress) * 0.8)
                                                    verticalSymbolScale = 0.6 + min(1.4, swipeProgress * 1.0)
                                                }
                                            } else {
                                                // Horizontal swipe - update horizontal offset
                                                cardOffset = horizontalDistance
                                                
                                                // If we were showing vertical symbols, hide them when switching to horizontal
                                                if isShowingFavoriteSymbol || isShowingHiddenSymbol {
                                                    verticalSymbolOpacity = 0
                                                    isShowingFavoriteSymbol = false
                                                    isShowingHiddenSymbol = false
                                                    // Reset vertical offset too
                                                    cardVerticalOffset = 0
                                                }
                                                
                                                // Determine which symbol to show based on swipe direction
                                                if horizontalDistance > 0 {
                                                    // Swiping right - show complete symbol
                                                    isShowingCompleteSymbol = true
                                                    isShowingSkipSymbol = false
                                                    
                                                    // Update symbol position and opacity
                                                    symbolOffset = -geometry.size.width/2 + horizontalDistance/2
                                                    
                                                    // Calculate progress toward threshold
                                                    let swipeProgress = abs(horizontalDistance) / horizontalSwipeThreshold
                                                    
                                                    // Gradually increase opacity and scale
                                                    symbolOpacity = min(1.0, Double(swipeProgress) * 0.8)
                                                    symbolScale = 0.6 + min(1.4, swipeProgress * 1.0)
                                                } else if horizontalDistance < 0 {
                                                    // Swiping left - show skip symbol
                                                    isShowingSkipSymbol = true
                                                    isShowingCompleteSymbol = false
                                                    
                                                    // Update symbol position and opacity
                                                    symbolOffset = geometry.size.width/2 + horizontalDistance/2
                                                    
                                                    // Calculate progress toward threshold
                                                    let swipeProgress = abs(horizontalDistance) / horizontalSwipeThreshold
                                                    
                                                    // Gradually increase opacity and scale
                                                    symbolOpacity = min(1.0, Double(swipeProgress) * 0.8)
                                                    symbolScale = 0.6 + min(1.4, swipeProgress * 1.0)
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
                                                if abs(verticalDistance) > verticalSwipeThreshold {
                                                    if verticalDistance < 0 {
                                                        // Swiped up past threshold - toggle favorite
                                                        toggleFavorite()
                                                    } else {
                                                        // Swiped down past threshold - toggle hidden
                                                        toggleHidden()
                                                    }
                                                } else {
                                                    // Not past threshold - reset
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
                        
                        // Card content
                        Text(cardText)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding()
                            .offset(x: cardOffset, y: 0)
                            .opacity(cardOpacity)
                        
                        // Skip symbol (circle with slash)
                        ZStack {
                            Circle()
                                .fill(skipSymbolColor)
                                .frame(width: symbolSize, height: symbolSize)
                            Image(systemName: "slash.circle")
                                .foregroundColor(.white)
                                .font(.system(size: symbolSize * 0.6))
                        }
                        .scaleEffect(symbolScale)
                        .opacity(isShowingSkipSymbol ? symbolOpacity : 0)
                        .offset(x: symbolOffset)
                        .allowsHitTesting(false) // Prevent symbol from blocking card gesture
                        
                        // Complete symbol (checkmark)
                        ZStack {
                            Circle()
                                .fill(completeSymbolColor)
                                .frame(width: symbolSize, height: symbolSize)
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: symbolSize * 0.6))
                        }
                        .scaleEffect(symbolScale)
                        .opacity(isShowingCompleteSymbol ? symbolOpacity : 0)
                        .offset(x: symbolOffset)
                        .allowsHitTesting(false) // Prevent symbol from blocking card gesture
                        
                        // Favorite symbol (star)
                        ZStack {
                            Circle()
                                .fill(favoriteSymbolColor)
                                .frame(width: symbolSize, height: symbolSize)
                            Image(systemName: "star.fill")
                                .foregroundColor(.white)
                                .font(.system(size: symbolSize * 0.6))
                        }
                        .scaleEffect(verticalSymbolScale)
                        .opacity(isShowingFavoriteSymbol ? verticalSymbolOpacity : 0)
                        .offset(y: verticalSymbolOffset)
                        .allowsHitTesting(false)
                        
                        // Hidden symbol (eye slash)
                        ZStack {
                            Circle()
                                .fill(hiddenSymbolColor)
                                .frame(width: symbolSize, height: symbolSize)
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(.white)
                                .font(.system(size: symbolSize * 0.6))
                        }
                        .scaleEffect(verticalSymbolScale)
                        .opacity(isShowingHiddenSymbol ? verticalSymbolOpacity : 0)
                        .offset(y: verticalSymbolOffset)
                        .allowsHitTesting(false)
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
                        .fill(topOverlayColor)
                        .frame(height: geometry.size.height - topBarHeight)
                    
                    // Top overlay handle - draggable
                    Rectangle()
                        .fill(isHidden ? hiddenHandleColor : (isFavorite ? favoriteHandleColor : topHandleColor))
                        .frame(height: topBarHeight)
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
                                    
                                    withAnimation(.easeInOut(duration: 0.3)) {
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
                .animation(.easeInOut(duration: 0.3), value: topOverlayOffset)
                
                // MARK: - Bottom Overlay
                
                // Bottom Overlay with handle and body
                VStack(spacing: 0) {
                    // Bottom overlay handle - draggable
                    Rectangle()
                        .fill(isHidden ? hiddenHandleColor : (isFavorite ? favoriteHandleColor : bottomHandleColor))
                        .frame(height: bottomBarHeight)
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
                                    
                                    withAnimation(.easeInOut(duration: 0.3)) {
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
                        .fill(bottomOverlayColor)
                        .frame(height: geometry.size.height - bottomBarHeight)
                }
                .offset(y: geometry.size.height - bottomBarHeight - safeAreaBottom - bottomOverlayOffset)
                .zIndex(bottomOverlayActive ? 2 : 1)
                .animation(.easeInOut(duration: 0.3), value: bottomOverlayOffset)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
