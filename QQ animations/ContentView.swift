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
    
    // States for horizontal card swipe
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 1.0
    @State private var symbolOffset: CGFloat = 0
    @State private var symbolOpacity: Double = 0.0
    @State private var symbolScale: CGFloat = 0.6
    @State private var isShowingSkipSymbol: Bool = false
    @State private var isShowingCompleteSymbol: Bool = false
    @State private var isCardSwiped: Bool = false
    @State private var newCardOpacity: Double = 0.0
    
    // State for the card text (random number for testing)
    @State private var cardText: String = "\(Int.random(in: 1000000...9999999))"
    @State private var newCardText: String = "\(Int.random(in: 1000000...9999999))"
    
    // Constants for overlay sizes
    let topBarHeight: CGFloat = 50
    let bottomBarHeight: CGFloat = 50
    let cardHeight: CGFloat = 300
    
    // Constants for swipe thresholds
    let swipeThreshold: CGFloat = 100
    let symbolSize: CGFloat = 40
    
    // Defined colors for better consistency
    let topHandleColor = Color(red: 0.0, green: 0.4, blue: 0.8) // Deeper blue
    let topOverlayColor = Color(red: 0.1, green: 0.5, blue: 0.9) // Lighter blue
    let bottomHandleColor = Color(red: 0.5, green: 0.0, blue: 0.7) // Deep purple
    let bottomOverlayColor = Color(red: 0.6, green: 0.1, blue: 0.8) // Lighter purple
    let skipSymbolColor = Color(red: 0.6, green: 0.2, blue: 0.2) // Red
    let completeSymbolColor = Color(red: 0.2, green: 0.6, blue: 0.2) // Green
    
    // Get the safe area insets directly from UIKit
    var safeAreaTop: CGFloat {
        UIApplication.safeAreaInsets.top
    }
    
    var safeAreaBottom: CGFloat {
        UIApplication.safeAreaInsets.bottom
    }
    
    // Reset the card state but only when returning from a partial swipe
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
                        // "New" card that appears behind the current card
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: cardHeight)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            
                            Text(newCardText)
                                .font(.system(size: 24, weight: .bold))
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        .opacity(newCardOpacity)
                        
                        // Current card
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: cardHeight)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .offset(x: cardOffset)
                            .opacity(cardOpacity)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // Only respond to horizontal gestures if not already swiped
                                        if !isCardSwiped {
                                            // Update card position
                                            cardOffset = value.translation.width
                                            
                                            // Determine which symbol to show based on swipe direction
                                            if cardOffset > 0 {
                                                // Swiping right - show complete symbol
                                                isShowingCompleteSymbol = true
                                                isShowingSkipSymbol = false
                                                
                                                // Update symbol position and opacity - make it more proportional to distance
                                                symbolOffset = -geometry.size.width/2 + cardOffset/2
                                                
                                                // Calculate progress toward threshold (0 to 1 and beyond)
                                                let swipeProgress = abs(cardOffset) / swipeThreshold
                                                
                                                // Gradually increase opacity as we approach and pass threshold
                                                symbolOpacity = min(1.0, Double(swipeProgress) * 0.8)
                                                
                                                // Scale symbol smoothly throughout the entire swipe
                                                symbolScale = 0.6 + min(1.4, swipeProgress * 1.0)
                                            } else if cardOffset < 0 {
                                                // Swiping left - show skip symbol
                                                isShowingSkipSymbol = true
                                                isShowingCompleteSymbol = false
                                                
                                                // Update symbol position and opacity - make it more proportional to distance
                                                symbolOffset = geometry.size.width/2 + cardOffset/2
                                                
                                                // Calculate progress toward threshold (0 to 1 and beyond)
                                                let swipeProgress = abs(cardOffset) / swipeThreshold
                                                
                                                // Gradually increase opacity as we approach and pass threshold
                                                symbolOpacity = min(1.0, Double(swipeProgress) * 0.8)
                                                
                                                // Scale symbol smoothly throughout the entire swipe
                                                symbolScale = 0.6 + min(1.4, swipeProgress * 1.0)
                                            } else {
                                                // Not swiping - hide both symbols
                                                isShowingSkipSymbol = false
                                                isShowingCompleteSymbol = false
                                                symbolOpacity = 0
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        if !isCardSwiped {
                                            if abs(cardOffset) > swipeThreshold {
                                                // If swiped past threshold, complete the swipe
                                                let direction: CGFloat = cardOffset > 0 ? 1 : -1
                                                completeCardSwipe(direction: direction)
                                            } else {
                                                // Otherwise, reset card position
                                                resetCardState()
                                            }
                                        }
                                    }
                            )
                        
                        // Card content
                        Text(cardText)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding()
                            .offset(x: cardOffset)
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
                        .fill(topHandleColor)
                        .frame(height: topBarHeight)
                        .contentShape(Rectangle()) // Ensure entire handle is tappable
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Activate this overlay while dragging
                                    topOverlayActive = true
                                    
                                    // Calculate new offset based on drag, with limits
                                    let newOffset = topOverlayOffset + value.translation.height
                                    // Calculate full slide distance to position precisely at bottom bar
                                    let maxOffset = geometry.size.height - (safeAreaTop + topBarHeight) - safeAreaBottom
                                    topOverlayOffset = min(maxOffset, max(0, newOffset))
                                }
                                .onEnded { value in
                                    // Snap to fully open or closed based on current position
                                    let threshold = (geometry.size.height - topBarHeight - safeAreaTop) / 2
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if topOverlayOffset > threshold {
                                            // Snap to fully open - positioned at bottom bar
                                            // Calculate full slide distance to position precisely at bottom bar
                                            let fullSlideDistance = geometry.size.height - (safeAreaTop + topBarHeight) - safeAreaBottom
                                            topOverlayOffset = fullSlideDistance
                                            // Keep active when open
                                            topOverlayActive = true
                                        } else {
                                            // Snap to closed
                                            topOverlayOffset = 0
                                            // Deactivate when closed
                                            topOverlayActive = false
                                        }
                                    }
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
                        .fill(bottomHandleColor)
                        .frame(height: bottomBarHeight)
                        .contentShape(Rectangle()) // Ensure entire handle is tappable
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Activate this overlay while dragging
                                    bottomOverlayActive = true
                                    
                                    // Calculate new offset based on drag, with limits
                                    let newOffset = bottomOverlayOffset - value.translation.height
                                    // Calculate full slide distance to position precisely at top bar
                                    let maxOffset = geometry.size.height - (safeAreaBottom + bottomBarHeight) - safeAreaTop
                                    bottomOverlayOffset = min(maxOffset, max(0, newOffset))
                                }
                                .onEnded { value in
                                    // Snap to fully open or closed based on current position
                                    let threshold = (geometry.size.height - bottomBarHeight - safeAreaBottom) / 2
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if bottomOverlayOffset > threshold {
                                            // Snap to fully open - positioned at top bar
                                            // Calculate full slide distance to position precisely at top bar
                                            let fullSlideDistance = geometry.size.height - (safeAreaBottom + bottomBarHeight) - safeAreaTop
                                            bottomOverlayOffset = fullSlideDistance
                                            // Keep active when open
                                            bottomOverlayActive = true
                                        } else {
                                            // Snap to closed
                                            bottomOverlayOffset = 0
                                            // Deactivate when closed
                                            bottomOverlayActive = false
                                        }
                                    }
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
